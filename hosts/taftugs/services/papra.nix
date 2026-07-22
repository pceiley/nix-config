# Papra - minimalist document archiving, gated by Kanidm SSO. Runs as a
# Podman quadlet rather than the native nixpkgs package - the container
# image is more actively maintained than the nix packaging, and quadlet's
# env handling goes through podman's own --env-file parsing (which keeps
# quote characters literal) rather than systemd's EnvironmentFile= parsing
# (which strips them as delimiters) - the latter is what corrupted
# AUTH_PROVIDERS_CUSTOMS' JSON when this ran as a native service.

{ config, pkgs, inputs, ... }:

let
  port = 1221;
  domain = "papra.roastlan.net";
in
{
  virtualisation.podman.enable = true;

  # Pin the same uid/gid the native service's DynamicUser was already
  # using (confirmed via `id papra` on taftugs), so /data/papra and
  # /var/lib/papra don't need re-chowning on this switchover.
  users.groups.papra = {
    gid = 979;
  };
  users.users.papra = {
    isSystemUser = true;
    group = "papra";
    uid = 981;
  };

  virtualisation.quadlet.autoUpdate = {
    enable = true;
    # Default is daily at midnight; matches the rest of your maintenance
    # windows closely enough not to need its own schedule.
  };

  virtualisation.quadlet.containers.papra = {
    containerConfig = {
      image = "ghcr.io/papra-hq/papra:latest-rootless";
      autoUpdate = "registry";

      environmentFiles = [ config.sops.templates."papra.env".path ];
      environments = {
        APP_BASE_URL = "https://${domain}";
        PORT = toString port;

        DOCUMENTS_CONTENT_EXTRACTION_ENABLED = "true";
        DOCUMENTS_OCR_LANGUAGES = "eng";
        DOCUMENT_STORAGE_MAX_UPLOAD_SIZE = "0";

        # Same paths in spirit as the native setup: documents on the ZFS
        # dataset, db/ingestion under state. Mounted below.
        DOCUMENT_STORAGE_FILESYSTEM_ROOT = "/app-data/documents";
        DATABASE_URL = "file:/app-data/state/db.sqlite";

        # Use the new pattern-based storage
        DOCUMENT_STORAGE_USE_LEGACY_STORAGE_KEY_DEFINITION_SYSTEM = "false";

        # Use the default storage pattern config
        # https://docs.papra.app/guides/storage-key-patterns/
        # DOCUMENT_STORAGE_KEY_PATTERN = "{{organization.id}}/{{document.name}}";
        # DOCUMENT_STORAGE_PATTERN_MAX_INCREMENTAL_SUFFIX_ATTEMPTS = "9";
        # DOCUMENT_STORAGE_PATTERN_ENABLE_RANDOM_SUFFIX_FALLBACK = "true";

        AUTH_FIRST_USER_AS_ADMIN = "true";

        INGESTION_FOLDER_IS_ENABLED = "true";
        INGESTION_FOLDER_ROOT_PATH = "/app-data/state/ingestion";
        INGESTION_FOLDER_POST_PROCESSING_STRATEGY = "delete";

        AUTH_PROVIDERS_EMAIL_IS_ENABLED = "false";
        AUTH_IS_REGISTRATION_ENABLED = "false";
      };

      volumes = [
        "/data/papra:/app-data/documents"
        "/var/lib/papra:/app-data/state"
      ];

      publishPorts = [ "127.0.0.1:${toString port}:${toString port}" ];

      # rootless *image* (accepts an arbitrary uid via --user, doesn't
      # hardcode 1000 internally) - not to be confused with rootless
      # *podman*; this container is still managed by the system podman
      # instance via a root-owned systemd unit. Uses the same papra
      # uid/gid declared above so host and container agree.
      podmanArgs = [
        "--user=${toString config.users.users.papra.uid}:${toString config.users.groups.papra.gid}"
      ];
    };

    serviceConfig = {
      Restart = "always";
    };

    unitConfig = {
      After = [ "zfs-mount.service" ];
      Requires = [ "zfs-mount.service" ];
    };
  };

  # Same papra uid/gid needs to own these on the host.
  systemd.tmpfiles.rules = [
    "d /var/lib/papra/ingestion 0750 ${toString config.users.users.papra.uid} ${toString config.users.groups.papra.gid} -"
  ];

  # Same cross-host shared secret as the other oauth2 clients: kanidm on
  # superslice sets the basic secret, papra here sends it back inside the
  # provider JSON. Both hosts decrypt the same secrets.yaml entry.
  sops.secrets."papra_auth_secret" = { };
  sops.secrets."papra_oauth2_secret" = { };

  # AUTH_PROVIDERS_CUSTOMS is single-line JSON. Under podman's --env-file
  # parsing (unlike systemd's EnvironmentFile=), embedded quote characters
  # are kept literal rather than stripped as delimiters, so this needs no
  # extra escaping - providerId "kanidm" -> Better Auth callback
  # /api/auth/oauth2/callback/kanidm.
  sops.templates."papra.env".content = ''
    AUTH_SECRET=${config.sops.placeholder."papra_auth_secret"}
    AUTH_PROVIDERS_CUSTOMS=[{"providerId":"kanidm","providerName":"Kanidm","providerIconUrl":"https://api.iconify.design/tabler:login-2.svg","clientId":"papra","clientSecret":"${config.sops.placeholder."papra_oauth2_secret"}","type":"oidc","discoveryUrl":"https://idm.roastlan.net/oauth2/openid/papra/.well-known/openid-configuration","scopes":["openid","profile","email"],"pkce":true}]
  '';

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    useACMEHost = "roastlan.net";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    };
  };
}

# Papra - minimalist document archiving, gated by Kanidm SSO

{ config, lib, pkgs, inputs, ... }:

let
  port = 1221;
  domain = "papra.roastlan.net";
in
{
  disabledModules = [ "services/web-apps/papra.nix" ];
  imports = [ "${inputs.nixpkgs-unstable}/nixos/modules/services/web-apps/papra.nix" ];

  services.papra = {
    enable = true;

    package = pkgs.unstable.papra;

    # AUTH_SECRET and the Kanidm client secret (embedded in AUTH_PROVIDERS_CUSTOMS)
    # come from the sops template below, never the nix store.
    environmentFile = config.sops.templates."papra.env".path;

    # Flat env-var interface (merged over the module defaults, which already put
    # the DB + document storage under /var/lib/papra via StateDirectory).
    environment = {
      APP_BASE_URL = "https://${domain}";
      SERVER_HOSTNAME = "127.0.0.1"; # nginx-only, like paperless
      PORT = port;

      # OCR / text extraction, the Paperless-style bit.
      DOCUMENTS_CONTENT_EXTRACTION_ENABLED = true;
      DOCUMENTS_OCR_LANGUAGES = "eng";

      # No upload size cap (default is 25 MiB).
      DOCUMENT_STORAGE_MAX_UPLOAD_SIZE = 0;

      # Document blobs live on a dedicated ZFS dataset (data/papra) instead of
      # /var/lib. The dataset is created out-of-band and owned by papra; the
      # service waits for zfs-mount (see below). The sqlite DB and the ingestion
      # folder stay under /var/lib/papra (StateDirectory).
      DOCUMENT_STORAGE_FILESYSTEM_ROOT = "/data/papra";

      # Customizable storage path: replace the opaque legacy keys
      # ({{organization.id}}/originals/{{document.id}}) with short, readable
      # paths. The document id is long and ugly, so we key on the name and let
      # Papra disambiguate collisions with an incremental suffix (invoice.pdf,
      # invoice_1.pdf, ...), using the random 8-char suffix only if those are
      # exhausted. Requires the legacy system off.
      DOCUMENT_STORAGE_USE_LEGACY_STORAGE_KEY_DEFINITION_SYSTEM = false;
      DOCUMENT_STORAGE_KEY_PATTERN = "{{organization.id}}/{{document.name}}";
      DOCUMENT_STORAGE_PATTERN_MAX_INCREMENTAL_SUFFIX_ATTEMPTS = 100;
      DOCUMENT_STORAGE_PATTERN_ENABLE_RANDOM_SUFFIX_FALLBACK = true;

      # First identity to log in becomes admin. With SSO that's the first
      # Kanidm user in papra.access who signs in.
      AUTH_FIRST_USER_AS_ADMIN = true;

      # Folder ingestion - the analog to Paperless's consume dir. NOTE: files
      # must go under a per-organization subfolder, e.g.
      #   /var/lib/papra/ingestion/org_<id>/scan.pdf
      INGESTION_FOLDER_IS_ENABLED = true;
      INGESTION_FOLDER_ROOT_PATH = "/var/lib/papra/ingestion";
      INGESTION_FOLDER_POST_PROCESSING_STRATEGY = "delete"; # or "move"

      # Once SSO works and you've logged in once, lock it to Kanidm-only by
      # uncommenting these (keeps random email signups out; SSO still creates
      # accounts on login). Leave commented until first successful SSO login so
      # you don't lock yourself out.
      AUTH_PROVIDERS_EMAIL_IS_ENABLED = false;
      AUTH_IS_REGISTRATION_ENABLED = false;
    };
  };

  # Same cross-host shared secret as the other oauth2 clients: kanidm on
  # superslice sets the basic secret, papra here sends it back inside the
  # provider JSON. Both hosts decrypt the same secrets.yaml entry.
  sops.secrets."papra_auth_secret" = { };
  sops.secrets."papra_oauth2_secret" = { };

  # AUTH_PROVIDERS_CUSTOMS must be single-line JSON (systemd EnvironmentFile).
  # providerId "kanidm" -> Better Auth callback /api/auth/oauth2/callback/kanidm.
  sops.templates."papra.env".content = ''
    AUTH_SECRET=${config.sops.placeholder."papra_auth_secret"}
    AUTH_PROVIDERS_CUSTOMS=[{"providerId":"kanidm","providerName":"Kanidm","providerIconUrl":"https://api.iconify.design/tabler:login-2.svg","clientId":"papra","clientSecret":"${config.sops.placeholder."papra_oauth2_secret"}","type":"oidc","discoveryUrl":"https://idm.roastlan.net/oauth2/openid/papra/.well-known/openid-configuration","scopes":["openid","profile","email"],"pkce":true}]
  '';

  # /data/papra is its own ZFS dataset
  systemd.services.papra = {
    after = [ "zfs-mount.service" ];
    requires = [ "zfs-mount.service" ];
  };

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    useACMEHost = "roastlan.net";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    };
  };
}

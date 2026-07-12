# kanidm identity provider. serves https/oidc at idm.roastlan.net, bound to
# loopback and reverse-proxied with TLS by nginx using the same *.roastlan.net
# wildcard cert as the other vhosts. kanidm speaks tls only, so it reads the
# acme cert directly (kanidm user joins the nginx group for read access) and is
# restarted to pick up renewals.
#
# groups/persons/oauth2 clients are provisioned declaratively. note: provisioned
# persons have NO credentials until you mint a reset token (see README), and the
# kanidm `domain` is effectively permanent once chosen.

{ config, pkgs, ... }:

let
  domain     = "roastlan.net";
  origin     = "https://idm.roastlan.net";
  certDir    = config.security.acme.certs."roastlan.net".directory;
  grafanaUrl = "https://grafana.roastlan.net";
in
{
  services.kanidm = {
    # secret-provisioning build is required to set the oauth2 basic secret.
    package = pkgs.kanidmWithSecretProvisioning_1_10;

    server = {
      enable = true;
      settings = {
        inherit domain origin;
        bindaddress = "127.0.0.1:8443";
        tls_chain = "${certDir}/fullchain.pem";
        tls_key   = "${certDir}/key.pem";
        http_client_address_info."x-forward-for" = [ "127.0.0.1" ];
        online_backup = {
          versions = 7;
          schedule = "30 00 * * *";   # 00:30 daily; restic grabs it at 01:00
        };
      };
    };

    client = {
      enable = true;
      settings.uri = origin;
    };

    provision = {
      enable = true;
      adminPasswordFile    = config.sops.secrets."kanidm/admin_password".path;
      idmAdminPasswordFile = config.sops.secrets."kanidm/idm_admin_password".path;

      groups = {
        "grafana.access" = { };   # gates who may log in to grafana
        "grafana.admins" = { };   # elevates to the grafana Admin role
        "mealie.users"  = { };   # regular Mealie access
        "mealie.admins" = { };   # Mealie admin
        "papra.access" = { };
        "qbittorrent.access" = { };
        "actual.access" = { };
        "paperless.users" = { };
      };

      persons = {
        # admin identity
        pceiley_a = {
          displayName = "Peter Admin";
          mailAddresses = [ "peter_a@ceiley.com" ];
          groups = [ "grafana.access" "grafana.admins" "mealie.admins" "qbittorrent.access" "actual.access" "paperless.users" "papra.access" ];
        };
        # less-privileged personal account
        pceiley = {
          displayName = "Peter Ceiley";
          mailAddresses = [ "peter@ceiley.com" ];
          groups = [ "grafana.access" "mealie.users" "qbittorrent.access" "actual.access" "paperless.users" "papra.access" ];
        };

        cceiley = {
          displayName = "Clare Ceiley";
          mailAddresses = [ "cjceiley@gmail.com" ];
          groups = [ "mealie.users" "actual.access" "paperless.users" "papra.access" ];
        };
      };

      systems.oauth2.actual = {
        displayName = "Actual Budget";
        originUrl = "https://budget.roastlan.net/openid/callback";
        originLanding = "https://budget.roastlan.net/";
        basicSecretFile = config.sops.secrets."actual_oauth2_secret".path;
        preferShortUsername = true;
        # actual's openid-client only accepts RS256 id_tokens; kanidm signs
        # ES256 by default, so opt this client into legacy (RS256) crypto.
        enableLegacyCrypto = true;
        # actual does its own per-budget authz, so no group claim needed.
        scopeMaps."actual.access" = [ "openid" "email" "profile" ];
      };

      systems.oauth2.grafana = {
        displayName = "Grafana";
        originUrl = "${grafanaUrl}/login/generic_oauth";
        originLanding = "${grafanaUrl}/";
        basicSecretFile = config.sops.secrets."grafana_oauth2_secret".path;
        preferShortUsername = true;   # preferred_username = short name, not spn
        scopeMaps."grafana.access" = [ "openid" "email" "profile" "groups" ];
      };

      systems.oauth2.mealie = {
        displayName = "Mealie";
        originUrl = [
          "https://mealie.roastlan.net/login"
          "https://mealie.roastlan.net/login?direct=1"
        ];
        originLanding = "https://mealie.roastlan.net/";
        basicSecretFile = config.sops.secrets."mealie_oauth2_secret".path;
        preferShortUsername = true;
        # both groups need scopes, since admins may not be in mealie.users
        scopeMaps."mealie.users"  = [ "openid" "email" "profile" "groups" ];
        scopeMaps."mealie.admins" = [ "openid" "email" "profile" "groups" ];
      };

      systems.oauth2.qbittorrent = {
        displayName = "qBittorrent";
        originUrl = "https://bt.roastlan.net/oauth2/callback";
        originLanding = "https://bt.roastlan.net/";
        basicSecretFile = config.sops.secrets."qbittorrent_oauth2_secret".path;
        preferShortUsername = true;
        scopeMaps."qbittorrent.access" = [ "openid" "email" "profile" "groups" ];
      };

      systems.oauth2.paperless = {
        displayName = "Paperless";
        # django-allauth's openid_connect provider builds the callback as
        # /accounts/oidc/<provider_id>/login/callback/; provider_id is "kanidm".
        originUrl = "https://paperless.roastlan.net/accounts/oidc/kanidm/login/callback/";
        originLanding = "https://paperless.roastlan.net/";
        basicSecretFile = config.sops.secrets."paperless_oauth2_secret".path;
        preferShortUsername = true;
        # kanidm returns groups as SPNs, so the Paperless-side Django group
        # (created manually, see README) must be named with the full
        # "<name>@roastlan.net" suffix to match on sync.
        scopeMaps."paperless.users" = [ "openid" "email" "profile" "groups" ];
      };

      systems.oauth2.papra = {
        displayName = "Papra";
        # Better Auth's generic OAuth plugin builds the callback as
        # /api/auth/oauth2/callback/<providerId>; providerId is "kanidm".
        originUrl = "https://papra.roastlan.net/api/auth/oauth2/callback/kanidm";
        originLanding = "https://papra.roastlan.net/";
        basicSecretFile = config.sops.secrets."papra_oauth2_secret".path;
        preferShortUsername = true;
        # papra does its own per-account authz + first-login-admin, no group claim needed.
        scopeMaps."papra.access" = [ "openid" "email" "profile" ];
      };
    };
  };

  # kanidm reads the wildcard cert directly (group-readable by the nginx group)
  # and is restarted on renewal, since it has no hot cert reload.
  users.users.kanidm.extraGroups = [ config.services.nginx.group ];
  security.acme.certs."roastlan.net".reloadServices = [ "kanidm.service" ];

  # tls-terminating reverse proxy. backend is https on loopback with a cert for
  # idm.roastlan.net, so verification is skipped on the loopback hop.
  services.nginx.virtualHosts."idm.roastlan.net" = {
    forceSSL = true;
    useACMEHost = "roastlan.net";
    locations."/" = {
      proxyPass = "https://127.0.0.1:8443";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_ssl_verify off;
        proxy_ssl_server_name on;
        proxy_ssl_name idm.roastlan.net;
      '';
    };
  };

  sops.secrets = {
    "kanidm/admin_password".owner = "kanidm";
    "kanidm/idm_admin_password".owner = "kanidm";

    "actual_oauth2_secret".owner = "kanidm";
    "grafana_oauth2_secret".owner = "kanidm";
    "mealie_oauth2_secret".owner = "kanidm";
    "qbittorrent_oauth2_secret".owner = "kanidm";
    "paperless_oauth2_secret".owner = "kanidm";
    "papra_oauth2_secret".owner = "kanidm";
  };
}

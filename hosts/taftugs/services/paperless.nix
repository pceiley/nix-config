# Paperless

{ pkgs, config, ... }:

{
  services.paperless = {
    enable = true;
    address = "127.0.0.1";
    mediaDir = "/data/family/paperless";
    settings.PAPERLESS_ADMIN_USER = "paperless_a";
    settings.PAPERLESS_FILENAME_FORMAT = "{created_year}/{correspondent}/{title}";
    settings.PAPERLESS_URL = "https://paperless.roastlan.net";

    # OIDC via kanidm (django-allauth). password login stays available as a
    # fallback; PAPERLESS_DISABLE_REGULAR_LOGIN is intentionally left unset.
    settings.PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
    settings.PAPERLESS_SOCIAL_AUTO_SIGNUP = true; # auto-create the paperless user on first login
    # Sync kanidm's paperless.users group on every login. Paperless only
    # *joins/leaves* users to groups that already exist here by exact name -
    # it does not create them. The group (and its Django permissions) must be
    # created once via the admin UI before first login:
    # Settings -> Users & Groups -> Groups, named exactly:
    #   paperless.users@roastlan.net
    # (kanidm returns group membership as SPNs, hence the @roastlan.net
    # suffix - same convention as the mealie OIDC_USER_GROUP setup.)
    # This only grants whatever Django permissions that group carries; it
    # does not confer is_superuser. pceiley_a stays the real admin via its
    # local superuser account.
    settings.PAPERLESS_SOCIAL_ACCOUNT_SYNC_GROUPS = true;

    # PAPERLESS_SOCIALACCOUNT_PROVIDERS carries the client secret, so it's built
    # entirely in the sops-templated env file below rather than `settings`
    # (settings values land in the unit file, which is world-readable).
    environmentFile = config.sops.templates."paperless-oidc.env".path;
  };

  sops.secrets."paperless_oauth2_secret" = { };
  sops.templates."paperless-oidc.env".content = ''
    PAPERLESS_SOCIALACCOUNT_PROVIDERS={"openid_connect":{"OAUTH_PKCE_ENABLED":true,"SCOPE":["openid","profile","email","groups"],"APPS":[{"provider_id":"kanidm","name":"Kanidm","client_id":"paperless","secret":"${config.sops.placeholder."paperless_oauth2_secret"}","settings":{"server_url":"https://idm.roastlan.net/oauth2/openid/paperless","token_auth_method":"client_secret_basic"}}]}}
  '';

  services.nginx = {
    virtualHosts."paperless.roastlan.net" =  {
      forceSSL = true;
      useACMEHost = "roastlan.net";
      locations."/" = {
        proxyPass = "http://${config.services.paperless.address}:${toString config.services.paperless.port}";
      };
    };
  };
}

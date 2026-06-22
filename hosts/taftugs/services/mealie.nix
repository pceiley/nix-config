# Mealie recipe manager

{ pkgs, config, ... }:

{

  services.mealie = {
    enable = true;
    listenAddress = "127.0.0.1";
    package = pkgs.unstable.mealie;
  };

  services.mealie.settings = {
      BASE_URL = "https://mealie.roastlan.net";
      OIDC_AUTH_ENABLED = "true";
      OIDC_PROVIDER_NAME = "Kanidm";
      OIDC_CONFIGURATION_URL =
        "https://idm.roastlan.net/oauth2/openid/mealie/.well-known/openid-configuration";
      OIDC_CLIENT_ID = "mealie";
      # kanidm returns groups as SPNs, so match the full name@domain
      OIDC_USER_GROUP  = "mealie.users@roastlan.net";
      OIDC_ADMIN_GROUP = "mealie.admins@roastlan.net";
      OIDC_SIGNUP_ENABLED = "true";    # auto-create the Mealie user on first login
      OIDC_AUTO_REDIRECT = "false";    # keep the login page with an OIDC button
    };

    services.mealie.credentialsFile = config.sops.templates."mealie-oidc.env".path;

    sops.secrets."mealie_oauth2_secret" = { };
    sops.templates."mealie-oidc.env".content = ''
      OIDC_CLIENT_SECRET=${config.sops.placeholder."mealie_oauth2_secret"}
    '';

  services.nginx = {
    virtualHosts."mealie.roastlan.net" =  {
      forceSSL = true;
      useACMEHost = "roastlan.net";
      locations."/" = {
        proxyPass = "http://${config.services.mealie.listenAddress}:${toString config.services.mealie.port}";
      };
    };
  };

}

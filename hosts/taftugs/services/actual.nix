# Actual Budget

{ pkgs, config, inputs, ... }:
{
  services.actual = {
    enable = true;
    # openFirewall = true;
    package = pkgs.unstable.actual-server;
    settings = {
      hostname = "127.0.0.1";
      port = 13000;

      # OIDC via kanidm. password login stays allowed as a lockout fallback
      # (enforceOpenId defaults false); openid just becomes the default method.
      loginMethod = "openid";
      # auto-create the user on first login. safe because entry is already
      # gated by the actual.access scope map in kanidm; without scopes the
      # token is refused and login never reaches actual.
      userCreationMode = "login";
      openId = {
        # kanidm's per-client issuer; openid-client appends
        # /.well-known/openid-configuration during discovery.
        discoveryURL = "https://idm.roastlan.net/oauth2/openid/actual";
        client_id = "actual";
        server_hostname = "https://budget.roastlan.net";
        # client_secret comes from the env file below, never the nix store.
      };
    };
  };

  # keep the client secret out of the world-readable store config.json: systemd
  # reads this EnvironmentFile as root at unit start, and the env var overrides
  # the (unset) openId.client_secret config key.
  sops.secrets."actual_oauth2_secret" = { };
  sops.templates."actual-oidc.env".content = ''
    ACTUAL_OPENID_CLIENT_SECRET=${config.sops.placeholder."actual_oauth2_secret"}
  '';
  systemd.services.actual.serviceConfig.EnvironmentFile =
    config.sops.templates."actual-oidc.env".path;

  services.nginx = {
    virtualHosts."budget.roastlan.net" =  {
      forceSSL = true;
      useACMEHost = "roastlan.net";
      locations."/" = {
        proxyPass = "http://${config.services.actual.settings.hostname}:${toString config.services.actual.settings.port}";
      };
    };
  };

}

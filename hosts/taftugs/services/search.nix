# SearXNG

{ pkgs, config, inputs, ... }:
{
  services.searx = {
    enable = true;
    package = pkgs.unstable.searxng;
    settings.server = {
      base_url = "https://search.roastlan.net";
      hostname = "127.0.0.1";
      port = 17429;
      secret_key = config.sops.secrets.searx_secret.path;
    };
  };

  services.nginx = {
    virtualHosts."search.roastlan.net" =  {
      forceSSL = true;
      useACMEHost = "roastlan.net";
      locations."/" = {
        proxyPass = "http://${config.services.searx.settings.server.hostname}:${toString config.services.searx.settings.server.port}";
      };
    };
  };

  sops.secrets = {
    "searx_secret" = {
      owner = config.users.users.searx.name;
    };
  };

}

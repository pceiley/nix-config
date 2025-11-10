# Paperless

{ pkgs, config, ... }:

{
  services.paperless = {
    enable = true;
    address = "127.0.0.1";
    mediaDir = "/data/family/paperless";
    settings.PAPERLESS_ADMIN_USER = "paperless_a";
    settings.PAPERLESS_FILENAME_FORMAT = "{created_year}/{correspondent}/{title}";
    settings.PAPERLESS_URL = "https://paperless.p.ceiley.net";
  };

  services.nginx = {
    virtualHosts."paperless.p.ceiley.net" =  {
      forceSSL = true;
      useACMEHost = "p.ceiley.net";
      locations."/" = {
        proxyPass = "http://${config.services.paperless.address}:${toString config.services.paperless.port}";
      };
    };
  };
}

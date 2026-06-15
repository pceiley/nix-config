# Mealie recipe manager

{ pkgs, config, ... }:

{

  services.mealie = {
    enable = true;
    listenAddress = "127.0.0.1";
    package = pkgs.unstable.mealie;
  };

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

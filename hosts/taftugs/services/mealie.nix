# Mealie recipe manager

{ pkgs, config, ... }:

{

  services.mealie = {
    enable = true;
    listenAddress = "127.0.0.1";
  };

  services.nginx = {
    virtualHosts."mealie.pc.roastlan.net" =  {
      forceSSL = true;
      useACMEHost = "pc.roastlan.net";
      locations."/" = {
        proxyPass = "http://${config.services.mealie.listenAddress}:${toString config.services.mealie.port}";
      };
    };
  };

}

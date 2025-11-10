# Mealie recipe manager

{ pkgs, config, ... }:

{

  services.mealie = {
    enable = true;
    listenAddress = "127.0.0.1";
    package = pkgs.unstable.mealie;
  };

  services.nginx = {
    virtualHosts."mealie.p.ceiley.net" =  {
      forceSSL = true;
      useACMEHost = "p.ceiley.net";
      locations."/" = {
        proxyPass = "http://${config.services.mealie.listenAddress}:${toString config.services.mealie.port}";
      };
    };
  };

}

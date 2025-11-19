# Jellyfin

{ pkgs, config, ... }:

let 
  address = "jellyfin.p.ceiley.net";
in
{

  systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "iHD";

  services.jellyfin = {
    enable = true;
    openFirewall = true;
    package = pkgs.unstable.jellyfin;
  };

  services.nginx = {
    virtualHosts."jellyfin.p.ceiley.net" =  {
      forceSSL = true;
      useACMEHost = "p.ceiley.net";
      locations."/" = {
        proxyPass = "http://localhost:8096";
        proxyWebsockets = true;
        extraConfig =
          # required when the target is also TLS server with multiple hosts
          "proxy_ssl_server_name on;" +
          # required when the server wants to use HTTP Authentication
          "proxy_pass_header Authorization;"
          ;
      };
    };
  };

}

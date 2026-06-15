# sabnzbd
#
{ pkgs, ... }:

{
  services.sabnzbd = {
    enable = true;
    group = "multimedia";
    openFirewall = true; # for the web interface
  };

  services.nginx = {
    virtualHosts."sabnzbd.roastlan.net" =  {
      forceSSL = true;
      useACMEHost = "roastlan.net";
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
      };
    };
  };

}

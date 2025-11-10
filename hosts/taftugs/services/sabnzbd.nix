# sabnzbd
#
{ pkgs, ... }:

#let
#  downloadDir = "/data/multimedia/downloads";
#  fixDownloadPerms = pkgs.writeShellScriptBin "fixdlperms" ''
#    find ${downloadDir} -type d -exec chmod 2775 {} +
#    find ${downloadDir} -type f -exec chmod 0664 {} +
#  '';
#in
{
  services.sabnzbd = {
    enable = true;
    group = "multimedia";
    openFirewall = true; # for the web interface
    #package = pkgs.unstable.qbittorrent-nox;
  };

  services.nginx = {
    virtualHosts."sabnzbd.p.ceiley.net" =  {
      forceSSL = true;
      useACMEHost = "p.ceiley.net";
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
      };
    };
  };

  ## Allow qbittorrent to save files in the multimedia share
  #users.users.qbittorrent.extraGroups = [ "multimedia" ];

  #environment.systemPackages = [ fixDownloadPerms ];
}

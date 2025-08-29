# qBittorrent service activation
#
# The shell script 'fixdlperms' is also created and should be added to the
# "Run external program on finished" section with the full path:
# /run/current-system/sw/bin/fixdlperms

{ pkgs, ... }:

let
  downloadDir = "/data/multimedia/downloads";
  fixDownloadPerms = pkgs.writeShellScriptBin "fixdlperms" ''
    find ${downloadDir} -type d -exec chmod 2775 {} +
    find ${downloadDir} -type f -exec chmod 0664 {} +
  '';
in
{
  services.qbittorrent = {
    enable = true;
    openFirewall = true;
    profileDir = "/srv/qbittorrent";
    #package = pkgs.unstable.qbittorrent-nox;
    webuiPort = 58080;
  };

  # Allow qbittorrent to save files in the multimedia share
  users.users.qbittorrent.extraGroups = [ "multimedia" ];

  environment.systemPackages = [ fixDownloadPerms ];
}

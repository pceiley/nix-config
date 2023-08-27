{ pkgs, ... }:

{
  services.qbittorrent = {
    enable = true;
    openFirewall = true;
    dataDir = "/srv/qbittorrent";
    port = 58080;
  };

  # Allow qbittorrent to save files in the multimedia share
  users.users.qbittorrent.extraGroups = [ "multimedia" ];
}

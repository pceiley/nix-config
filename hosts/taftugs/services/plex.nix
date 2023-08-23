# Plex

{ pkgs, ... }:

{
  services.plex = {
    enable = true;
    openFirewall = true;
    dataDir = "/srv/plex";
    package = pkgs.unstable.plex;
  };
}

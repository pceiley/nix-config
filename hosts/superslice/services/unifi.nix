# Unifi controller

{ pkgs, ... }:

{
  services.unifi = {
    enable = true;
    openFirewall = true;
    unifiPackage = pkgs.unifi;
    mongodbPackage = pkgs.pkgs.mongodb-7_0;
    maximumJavaHeapSize = 2048;
  };

  # Open firewall for web interface
  networking.firewall.allowedTCPPorts = [ 8443 ];
}

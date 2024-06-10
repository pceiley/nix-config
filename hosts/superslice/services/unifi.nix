# Unifi controller

{ pkgs, ... }:

{
  services.unifi = {
    enable = true;
    openFirewall = true;
    unifiPackage = pkgs.unifi8;
    maximumJavaHeapSize = 2048;
  };

  # Open firewall for web interface
  networking.firewall.allowedTCPPorts = [ 8443 ];
}

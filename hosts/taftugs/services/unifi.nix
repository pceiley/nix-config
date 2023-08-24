# Unifi controller

{ pkgs, ... }:

{
  services.unifi = {
    enable = true;
    openFirewall = true;
    unifiPackage = pkgs.unifi;
  };

  # Open firewall for web interface
  networking.firewall.allowedTCPPorts = [ 8443 ];
}

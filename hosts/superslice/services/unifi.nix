# Unifi controller

{ pkgs, ... }:

{
  services.unifi = {
    enable = true;
    openFirewall = true;
    jrePackage = pkgs.jdk25_headless;
    unifiPackage = pkgs.unstable.unifi;
    mongodbPackage = pkgs.pkgs.mongodb-7_0;
    maximumJavaHeapSize = 2048;
  };

  # Open firewall for web interface
  networking.firewall.allowedTCPPorts = [ 8443 ];
}

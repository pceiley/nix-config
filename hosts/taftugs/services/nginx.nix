# nginx setup - primarily for reverse proxy

{ pkgs, config, ... }:

{
  # https://nixos.wiki/wiki/Nginx
  services.nginx = {
    enable = true;

    # Use recommended settings
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
  };

  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
  };
}

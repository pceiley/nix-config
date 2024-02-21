# Reverse Proxy

{ pkgs, config, ... }:

{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
  };

  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
  };
}

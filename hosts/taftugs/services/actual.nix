# Actual Budget

{ pkgs, config, inputs, ... }:
{
  #imports = [
  #  "${inputs.nixpkgs-unstable}/nixos/modules/services/web-apps/actual.nix"
  #];

  services.actual = {
    enable = true;
    openFirewall = true;
    #package = pkgs.unstable.actual-server;
    settings = {
      hostname = "127.0.0.1";
      port = 13000;
    };
  };

  services.nginx = {
    virtualHosts."budget.pc.roastlan.net" =  {
      forceSSL = true;
      useACMEHost = "pc.roastlan.net";
      locations."/" = {
        proxyPass = "http://${config.services.actual.settings.hostname}:${toString config.services.actual.settings.port}";
      };
    };
  };

}

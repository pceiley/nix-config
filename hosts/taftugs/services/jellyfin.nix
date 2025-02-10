# Jellyfin

{ pkgs, config, ... }:

let 
  address = "jellyfin.pc.roastlan.net";
in
{
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime
    ];
  };

  services.jellyfin = {
    enable = true;
    openFirewall = true;
    package = pkgs.unstable.jellyfin;
  };

  services.nginx = {
    virtualHosts."jellyfin.pc.roastlan.net" =  {
      forceSSL = true;
      useACMEHost = "pc.roastlan.net";
      locations."/" = {
        proxyPass = "http://localhost:8096";
      };
    };
  };

}

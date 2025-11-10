# FreshRSS

{ pkgs, config, ... }:
let 
  address = "rss.p.ceiley.net";
in
{
  services.freshrss = {
    enable = true;
    dataDir = "/srv/freshrss";
    baseUrl = "https://${address}";
    defaultUser = "pc_admin";
    passwordFile = "/persist/secrets/freshrss-admin-pass.txt";
    virtualHost = address;
  };

  services.nginx = {
    virtualHosts."${address}" = {
      forceSSL = true;
      useACMEHost = "p.ceiley.net";
    };
  };
}

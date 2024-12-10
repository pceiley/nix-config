# FreshRSS

{ pkgs, config, ... }:
let 
  address = "rss.pc.roastlan.net";
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
      #serverAliases = [ "${address}" ];
      forceSSL = true;
      sslCertificateKey = "${config.security.acme.certs."pc.roastlan.net".directory}/key.pem";
      sslCertificate = "${config.security.acme.certs."pc.roastlan.net".directory}/cert.pem";
      #locations."/" = {
      #  proxyPass = "http://127.0.0.1:12345";
      #  proxyWebsockets = true; # needed if you need to use WebSocket
      #  extraConfig =
      #    # required when the target is also TLS server with multiple hosts
      #    "proxy_ssl_server_name on;" +
      #    # required when the server wants to use HTTP Authentication
      #    "proxy_pass_header Authorization;"
      #    ;
      #};
    };
  };
}

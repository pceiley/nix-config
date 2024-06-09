# Paperless

{ pkgs, config, ... }:

{
  services.paperless = {
    enable = true;
    mediaDir = "/data/family/paperless";
    settings.PAPERLESS_ADMIN_USER = "paperless_a";
    settings.PAPERLESS_FILENAME_FORMAT = "{created_year}/{correspondent}/{title}";
  };

  services.nginx = {
    virtualHosts."paperless.pc.roastlan.net" =  {
      serverAliases = [ "paperless.pc.roastlan.net" ];
      forceSSL = true;
      #enableACME = true;
      sslCertificateKey = "${config.security.acme.certs."pc.roastlan.net".directory}/key.pem";
      sslCertificate = "${config.security.acme.certs."pc.roastlan.net".directory}/cert.pem";
      locations."/" = {
        proxyPass = "http://127.0.0.1:28981";
        proxyWebsockets = true; # needed if you need to use WebSocket
        extraConfig =
          # required when the target is also TLS server with multiple hosts
          "proxy_ssl_server_name on;" +
          # required when the server wants to use HTTP Authentication
          "proxy_pass_header Authorization;"
          ;
      };
    };
  };
}

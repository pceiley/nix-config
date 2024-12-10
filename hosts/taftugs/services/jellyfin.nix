# Jellyfin

{ pkgs, config, ... }:

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
      serverAliases = [ "jellyfin-ts.pc.roastlan.net" ];
      forceSSL = true;
      #enableACME = true;
      sslCertificateKey = "${config.security.acme.certs."pc.roastlan.net".directory}/key.pem";
      sslCertificate = "${config.security.acme.certs."pc.roastlan.net".directory}/cert.pem";
      locations."/" = {
        proxyPass = "http://127.0.0.1:8096";
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

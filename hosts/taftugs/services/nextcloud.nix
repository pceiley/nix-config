# Nextcloud
#
# Based on
# https://carjorvaz.com/posts/the-holy-grail-nextcloud-setup-made-easy-by-nixos/

{ pkgs, config, ... }:
let ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  services.nextcloud = {
    enable = true;
    hostName = "cloud.pc.roastlan.net";
    
    # Need to manually increment with every major upgrade.
    package = pkgs.nextcloud28;

    # Let NixOS install and configure the database automatically.
    database.createLocally = true;

    datadir = "/data/nextcloud";

    # Let NixOS install and configure Redis caching automatically.
    configureRedis = true;

    # Increase the maximum file upload size to avoid problems uploading videos.
    maxUploadSize = "16G";
    https = true;

    autoUpdateApps.enable = true;
    extraAppsEnable = true;
    extraApps = with config.services.nextcloud.package.packages.apps; {
        # List of apps we want to install and are already packaged in
        # https://github.com/NixOS/nixpkgs/blob/master/pkgs/servers/nextcloud/packages/nextcloud-apps.json
        inherit calendar contacts cookbook notes tasks;

        # Custom app installation example.
        #cookbook = pkgs.fetchNextcloudApp rec {
        #  url =
        #    "https://github.com/nextcloud/cookbook/releases/download/v0.10.2/Cookbook-0.10.2.tar.gz";
        #  sha256 = "sha256-XgBwUr26qW6wvqhrnhhhhcN4wkI+eXDHnNSm1HDbP6M=";
        #};
    };

    settings = {
      overwriteprotocol = "https";
      default_phone_region = "AU";
      "localstorage.umask" = "0007";
    };
   
    config = {
      dbtype = "pgsql";
      adminuser = "pc_admin";
      adminpassFile = "/persist/secrets/nextcloud-admin-pass.txt";
    };

#    extraOptions = {
#      "localstorage.umask" = "0007";
#    };

  };

  users.users.nextcloud.extraGroups = ifTheyExist [ "family" ];

  services.nginx = {
    virtualHosts."cloud.pc.roastlan.net" =  {
      #serverAliases = [ "cloud.pc.roastlan.net" ];
      forceSSL = true;
      sslCertificateKey = "${config.security.acme.certs."pc.roastlan.net".directory}/key.pem";
      sslCertificate = "${config.security.acme.certs."pc.roastlan.net".directory}/cert.pem";
      #locations."/" = {
      #  proxyPass = "http://127.0.0.1:28981";
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

  # Backup
  services.postgresqlBackup = {
    enable = true;
    databases = [ "nextcloud" ];
    location = "/data/backup/nextcloud";
  };

}

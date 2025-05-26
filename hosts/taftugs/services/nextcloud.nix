# Nextcloud
#
# Based on
# https://carjorvaz.com/posts/the-holy-grail-nextcloud-setup-made-easy-by-nixos/

{ pkgs, config, ... }:
let
  address = "cloud.pc.roastlan.net";
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  services.nextcloud = {
    enable = true;
    #hostName = "cloud.pc.roastlan.net";
    hostName = "${address}";
    
    # Need to manually increment with every major upgrade.
    package = pkgs.nextcloud31;

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
      #adminpassFile = "/persist/secrets/nextcloud-admin-pass.txt";
      adminpassFile = config.sops.secrets.nextcloud_admin_password.path;
    };

  };

  users.users.nextcloud.extraGroups = ifTheyExist [ "family" ];

  services.nginx = {
    virtualHosts."cloud.pc.roastlan.net" =  {
      #serverAliases = [ "cloud.pc.roastlan.net" ];
      forceSSL = true;
      useACMEHost = "pc.roastlan.net";
    };
  };

  # Backup
  services.postgresqlBackup = {
    enable = true;
    databases = [ "nextcloud" ];
    location = "/data/backup/nextcloud";
  };

  sops.secrets = {
    "nextcloud_admin_password" = {
      owner = config.users.users.nextcloud.name;
    };
  };

}

# CouchDB
#
# https://github.com/vrtmrz/obsidian-livesync/blob/main/docs/setup_own_server.md#setup-a-couchdb-server
#
# 

{ pkgs, config, ... }:

{

  services.couchdb = {
    enable = true;
    #bindAddress = "127.0.0.1";
    #adminPass = "";
    extraConfigFiles = [ config.sops.secrets.couchdb-admin-ini.path ];
  };

  services.nginx = {
    virtualHosts."couchdb.p.ceiley.net" =  {
      forceSSL = true;
      useACMEHost = "p.ceiley.net";
      locations."/" = {
        proxyPass = "http://${config.services.couchdb.bindAddress}:${toString config.services.couchdb.port}";
        extraConfig =
          # https://docs.couchdb.org/en/stable/best-practices/reverse-proxies.html
          "proxy_buffering off;"
          ;
      };
    };
  };

  sops.secrets.couchdb-admin-ini = {
    owner = config.users.users.couchdb.name;
  };

}

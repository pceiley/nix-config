# Immich photo manager
#
# storage template {{#if album}}{{album}}{{else}}Other/{{y}}{{/if}}/{{filename}}
{ pkgs, config, ... }:
{
  services.immich = {
    accelerationDevices = [ "/dev/dri/renderD128" ];
    enable = true;
    mediaLocation = "/data/immich";
    port = 12283;
    host = "localhost";
    package = pkgs.unstable.immich;
    machine-learning = {
      enable = true;
      environment = {
        # https://github.com/nixos/nixpkgs/issues/418799
        HF_XET_CACHE = "/var/cache/immich/huggingface-xet";
        MPLCONFIGDIR = "/var/cache/immich/matplotlib";
      };
    };
  };
  users.users.immich.extraGroups = [ "video" "render" ];
  services.nginx = {
    virtualHosts."photos.ceiley.com" =  {
      forceSSL = true;
      useACMEHost = "photos.ceiley.com";
      locations."/" = {
        proxyPass = "http://[::1]:${toString config.services.immich.port}";
        proxyWebsockets = true;
        recommendedProxySettings = true;
        extraConfig = ''
          client_max_body_size 50000M;
          proxy_read_timeout   600s;
          proxy_send_timeout   600s;
          send_timeout         600s;
        '';
      };
    };
  };
}

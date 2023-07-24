{ config, pkgs, ... }:
let
  podsID = 888;
  mediaID = 800; 
in
{
  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];

  networking.firewall.allowedTCPPorts = [ 58080 ];

  users.users = {
    pods = {
      isSystemUser = true;
      uid = podsID;
      group = "pods";
      extraGroups = [ "media" ];
    };    
  };      
  users.groups.pods = {
    gid = podsID;
  };

  systemd.tmpfiles.rules = [
    "d /srv/pods 0750 pods pods"
    "d /srv/pods/downloads 0750 pods pods"
    "d /srv/pods/qbittorrent 0750 pods pods"
  ];

  virtualisation.containers.enable = true;

  virtualisation.oci-containers.backend = "podman";

  # qBittorrent container
  # Remember to create /srv/pods/qbittorrent/wireguard/wg0.conf
  virtualisation.oci-containers.containers = {
    qbittorrent = {
      image = "ghcr.io/hotio/qbittorrent:latest";
      autoStart = true;
      ports = [ "58080:58080/tcp" ];
      environment = {
        PUID = "${toString podsID}";
        PGID = "${toString mediaID}";
        TZ = "Australia/Sydney";
        WEBUI_PORTS = "58080/tcp,58080/udp";
        VPN_ENABLED = "true";
        VPN_LAN_NETWORK = "192.168.0.0/16";
      };
      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--cap-add=NET_RAW"
        "--sysctl=net.ipv4.conf.all.src_valid_mark=1"
        "--sysctl=net.ipv6.conf.all.disable_ipv6=1"
      ];
      volumes = [
        "/srv/pods/qbittorrent:/config"
        "/srv/pods/downloads:/downloads"
        "/net/media/Staging:/nas-staging"
      ];
    };
  };
}

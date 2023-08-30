# qBittorrent podman container

{ config, pkgs, ... }:
let
  UID = 888;
  GID = 888; 
in
{
  virtualisation.containers.enable = true;
  virtualisation.oci-containers.backend = "podman";

  networking.firewall.allowedTCPPorts = [ 58080 ];

  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];
  
  users.users = {
    pod-qbittorrent = {
      isSystemUser = true;
      uid = UID;
      group = "pod-qbittorrent";
      extraGroups = [ "multimedia" ];
    };    
  };      
  users.groups.pod-qbittorrent = {
    gid = GID;
  };

  systemd.tmpfiles.rules = [
    "d /srv/qbittorrent 0755 pod-qbittorrent pod-qbittorrent"
  ];

  # qBittorrent container
  # Remember to create /srv/pods/qbittorrent/wireguard/wg0.conf
  virtualisation.oci-containers.containers = {
    qbittorrent = {
      image = "ghcr.io/hotio/qbittorrent:latest";
      autoStart = true;
      ports = [ "58080:58080/tcp" ];
      environment = {
        PUID = "${toString UID}";
        PGID = "${toString GID}";
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
        "/srv/qbittorrent:/config"
        "/data/multimedia/Staging:/staging"
      ];
    };
  };
}

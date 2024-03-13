# Unifi container on podman

{ config, pkgs, ... }:
let
  UID = 10001;
  GID = 10001; 
in
{
  virtualisation.containers.enable = true;
  virtualisation.oci-containers.backend = "podman";

  networking.firewall.allowedTCPPorts = [ 8080 8443 ];
  networking.firewall.allowedUDPPorts = [ 1900 3478 10001 ];

  users.users = {
    pod-unifi = {
      isSystemUser = true;
      uid = UID;
      group = "pod-unifi";
    };    
  };      
  users.groups.pod-unifi = {
    gid = GID;
  };

  systemd.tmpfiles.rules = [
    "d /srv/unifi 0755 pod-unifi pod-unifi"
  ];

  virtualisation.oci-containers.containers = {
    unifi = {
      image = "ghcr.io/linuxserver/unifi-controller:latest";
      autoStart = true;
      ports = [
        "8080:8080/tcp" # for device communication
        "8443:8443/tcp" # Unifi web admin port
        "3478:3478/udp" # Unifi STUN port
        "10001:10001/udp" # for AP discovery
        "1900:1900/udp" # for Make controller discoverable on L2 network option
      ];
      environment = {
        PUID = "${toString UID}";
        PGID = "${toString GID}";
        TZ = "Australia/Sydney";
        MEM_LIMIT = "1024";
        MEM_STARTUP = "1024";
      };
      volumes = [
        "/srv/unifi:/config"
      ];
    };
  };
}

# NFS mounts from cheddar (Synology NAS)
#

let
  serverIP = "192.168.10.2";
in
{
  fileSystems."/net/share" = {
    device = "${serverIP}:/volume1/share";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" ];
  };

  fileSystems."/net/media" = {
    device = "${serverIP}:/volume4/media";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" ];
  };
}

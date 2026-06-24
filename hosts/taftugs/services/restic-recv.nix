# Receives superslice's restic backups over sftp.
#
# superslice runs restic as root and connects here as restic-recv using its ssh
# host key, writing to /data/restic/superslice. That path lives on a dedicated
# ZFS dataset (data/restic, created out-of-band) and is intentionally NOT under
# /data/backup, so taftugs's own localbackup doesn't re-sweep the repo.

{ pkgs, ... }:

{
  users.users.restic-recv = {
    isSystemUser = true;
    group = "restic-recv";
    home = "/data/restic";
    shell = pkgs.bashInteractive;   # the sftp subsystem needs a valid shell
    openssh.authorizedKeys.keys = [
      # superslice's host pubkey: cat /etc/ssh/ssh_host_ed25519_key.pub
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN34faljMJQyv5Qq3FhpJbUOqnUq6kSWKN8OVe5xaiMj root@superslice"
    ];
  };
  users.groups.restic-recv = { };

  systemd.tmpfiles.rules = [
    "d /data/restic 0750 restic-recv restic-recv -"
    "d /data/restic/superslice 0700 restic-recv restic-recv -"
  ];
}

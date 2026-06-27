# Receives superslice's restic backups over sftp, writing to the USB disk.
#
# superslice runs restic as root and connects here as restic-recv using its ssh
# host key, writing to /mnt/usb-backup/restic-superslice (a DIFFERENT repo from
# taftugs's own restic-purecheese on the same disk - never the same repo).
#
# IMPORTANT: the receive dir is NOT created by tmpfiles. /mnt/usb-backup is an
# x-systemd.automount mountpoint; pre-creating a subdir under it risks shadowing
# the automount or writing to the underlying SSD when the USB is absent. Create
# it once, on the mounted disk, by hand:
#   sudo mkdir -p /mnt/usb-backup/restic-superslice
#   sudo chown restic-recv:restic-recv /mnt/usb-backup/restic-superslice
# Its existence then tracks the mount: USB absent -> dir absent -> superslice's
# backup fails loudly instead of writing to the wrong disk.

{ pkgs, ... }:

{
  users.users.restic-recv = {
    isSystemUser = true;
    group = "restic-recv";
    home = "/var/empty";            # no home on the removable disk
    shell = pkgs.bashInteractive;   # the sftp subsystem needs a valid shell
    openssh.authorizedKeys.keys = [
      # superslice's host pubkey: cat /etc/ssh/ssh_host_ed25519_key.pub
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDMAGTiqaZD2SEMFsXQUH+goPWvEv0dd/mVdWGaovXQy superslice"
    ];
  };
  users.groups.restic-recv = { };
}

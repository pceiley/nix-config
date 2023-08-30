# nix-config
Peter's NixOS config.

## Fresh Install Instructions

### Prep required if wiping existing system
* Ensure backups are made of:
   * /persist
   * /srv
   * /etc/machine-id
   * /etc/ssh/ssh_host*

### Install
1. Boot from minimal nixos usb
1. Wipe the SSD (wipefs -a /dev/disk/by-id/…)
1. Partition - boot + primary part - XFS - label "boot" and "nixos"
1. Mount partitions on /mnt
1. Create /mnt/persist
1. Copy required stuff into /mnt/persist
1. `Mkpasswd >username` and copy to /mnt/persist/secrets/passwords/username
1. Install git `$ nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#git`
1. `mkdir /mnt/nix-config`
1. git clone repo to /mnt/nix-config
1. `$ sudo nixos-install --no-root-passwd --flake /mnt/nix-config#hostname`
1. Reboot

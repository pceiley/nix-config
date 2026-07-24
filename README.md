# nix-config

Peter's NixOS config.

Hosts: **`taftugs`** and **`superslice`**. Build/switch with
`sudo nixos-rebuild switch --flake .#<hostname>` (or the `justfile` recipes).

Both hosts use **systemd-boot (UEFI)** with two partitions — an ESP at `/boot`
(FAT32, label `boot`) and root at `/` (XFS, label `nixos`). Neither host has a
swap partition or swap file — both use **zramSwap** instead. There is
**no impermanence** — the root filesystem is fully persistent.

## Secrets (sops-nix)

Secrets live encrypted in `secrets/secrets.yaml` and are safe to commit.
Each host decrypts them at boot using its **SSH ed25519 host key**
(`/etc/ssh/ssh_host_ed25519_key`), whose age identity is a recipient in
`.sops.yaml`. Current recipients: the `pceiley` user key plus the `taftugs` and
`superslice` host keys.

Consequences for a rebuild/reinstall:

- The login password, WireGuard config, restic password, etc. all come from
  sops — there are **no plaintext secret files** to place on disk anymore.
- On reinstall you **must restore the original `/etc/ssh/ssh_host_ed25519_key`**
  (and `.pub`), or the host can't decrypt anything on first boot.
- To onboard a **new** host: get its age key with
  `nix run nixpkgs#ssh-to-age -- -i /etc/ssh/ssh_host_ed25519_key.pub`, add it to
  `.sops.yaml`, then `sops updatekeys secrets/secrets.yaml`.

## Fresh Install Instructions

### Prep required if wiping an existing system

Back up, so the reinstalled host keeps its identity and data:

* **Identity (required for sops + stable host identity):**
  * `/etc/ssh/ssh_host*`  ← the sops decryption key; without it secrets won't decrypt
  * `/etc/machine-id`
* **Application data:**
  * `/srv` (e.g. `/srv/plex`, `/srv/qbittorrent`, `/srv/unifi`)
  * `/var/lib` for service/database state (postgresql, paperless, immich, etc. —
    confirm per service `dataDir`)
* On `taftugs`, most service data actually lives on the ZFS **`data`** pool
  (`zfs.extraPools = [ "data" ]` in the host config), not on the root disk —
  the samba shares, Papra, Paperless media, etc. **Do not wipe or repartition
  those disks** when reinstalling; only the boot/root disk gets wiped. The
  pool is re-imported automatically on boot as long as `networking.hostId`
  in the host config (currently `8ec040f1`) matches what created the pool —
  if you ever need to import it manually: `zpool import -f data`.
* On `taftugs`, the local restic repo lives on the external disk mounted at
  `/mnt/usb-backup` (separate UUID-mounted ext4) — leave that disk untouched.

### Install

1. Boot from a minimal NixOS USB.
1. Wipe the SSD: `wipefs -a /dev/disk/by-id/…`
1. Partition (GPT):
   * ESP: ~1 GiB, type EFI System — `mkfs.vfat -F32 -n boot /dev/disk/by-id/…-part1`
   * Root: remainder — `mkfs.xfs -L nixos /dev/disk/by-id/…-part2`
   * The labels **must** be exactly `boot` and `nixos` to match the `by-label`
     mounts in the host config.
1. Mount: `mount /dev/disk/by-label/nixos /mnt` then
   `mkdir -p /mnt/boot && mount /dev/disk/by-label/boot /mnt/boot`
1. **Restore identity before installing** so the system keeps its host key and can
   decrypt sops on first boot:
   * `install -d -m700 /mnt/etc/ssh` and copy the backed-up `ssh_host_*` into it
   * copy the backed-up `/etc/machine-id` to `/mnt/etc/machine-id`
1. Restore application data into `/mnt/srv` (and `/mnt/var/lib` as needed).
1. Get git: `nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#git`
1. Clone the repo: `mkdir /mnt/nix-config && git clone <repo> /mnt/nix-config`
1. Install: `sudo nixos-install --no-root-passwd --flake /mnt/nix-config#<hostname>`
   (`<hostname>` = `taftugs` or `superslice`).
1. Reboot.

### After first boot

1. Confirm login works (the password comes from sops via the restored host key)
   and that key-based SSH works as a fallback.
1. `systemctl --failed` should be empty; spot-check `journalctl -b -p err`.
1. On `taftugs`, confirm the Mullvad namespace: `just vpn-check`.

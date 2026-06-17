# UniFi OS Server VM (superslice)

Migrating off the standalone UniFi Network Application (`services/unifi.nix`,
now disabled) onto Ubiquiti's UniFi OS Server, self-hosted inside a libvirt
VM ("halloumi") on superslice.

## Why a VM and not a container

Ubiquiti doesn't officially support running UniFi OS Server in
Docker/Podman directly on the host - it's an installer that bakes in a
podman container *plus* host-level systemd units, udev rules and network
setup for device discovery/adoption. The supported path is a dedicated
Ubuntu/Debian box, so a VM gives us that without dedicating real hardware.

## 1. Host config (this repo)

`hosts/superslice/services/virtualisation.nix` does two things:

- Enables `libvirtd` (KVM/QEMU + OVMF for UEFI guests), and allows guests to
  attach to a new `br0` bridge.
- Converts superslice's networking from "static IP on eno1" to "eno1 is a
  bridge port of br0, br0 carries the IP". This is required so VMs get real
  192.168.5.0/24 addresses (L2-adjacent to your UniFi devices) rather than
  being stuck behind libvirt's default NAT (`virbr0`), which would break
  device discovery/adoption.

Apply with the usual:

```fish
rebuild-host
```

After this, `pceiley` is in the `libvirtd` group (already wired up via
`ifTheyExist` in `hosts/common/users/pceiley`) - log out/in (or
`newgrp libvirtd`) to pick it up.

## 2. Create the guest VM

`hosts/superslice/services/unifi-os-vm/` contains:

- `user-data.yaml` / `meta-data.yaml` - cloud-init seed: creates the
  `pceiley` user with your SSH key, installs podman + deps (podman 4.3.1+,
  slirp4netns, uidmap - the UniFi OS Server prerequisites), enables the qemu
  guest agent, and turns on `unattended-upgrades` (security updates, with an
  automatic reboot window at 04:00 - tweak in `user-data.yaml`).
- `network-config.yaml` - cloud-init network config giving the VM a static
  IP of **192.168.5.6** on `ens2` (gateway/DNS 192.168.5.254). Adjust the
  address here if you want a different one.
- `create-vm.sh` - downloads a base cloud image (Ubuntu 26.04 LTS
  "Resolute Raccoon" by default; Debian 13 and Ubuntu 24.04 are left in as
  commented-out alternatives), makes a standalone 60GB qcow2 disk (a full
  copy, not a backing-file overlay, so the VM doesn't depend on the base
  image afterwards), builds the cloud-init seed ISO, and `virt-install`s the
  VM attached to `br0` (4 vCPU / 8GB RAM - adjust to taste, official minimum
  is 2 vCPU / 4GB / 25GB).

```fish
cd ~/nix-config/hosts/superslice/services/unifi-os-vm
./create-vm.sh
```

The VM comes up on the static IP **192.168.5.6**.

## Tearing down / starting from scratch
 
To completely purge the VM and its storage so you can re-run `create-vm.sh`
cleanly:
 
````fish
# Stop it if it's running (ignore "domain is not running" if already off)
sudo virsh destroy halloumi
 
# Remove the domain definition, its disks, and the UEFI NVRAM varstore.
# The --nvram flag is required for UEFI guests or undefine will refuse.
sudo virsh undefine halloumi --remove-all-storage --nvram
 
# Belt-and-braces: remove any leftover disk/seed artifacts by hand
sudo rm -f /var/lib/libvirt/images/halloumi.qcow2 \
           /var/lib/libvirt/images/halloumi-seed.iso
 
# Confirm it's gone (should not list "halloumi")
sudo virsh list --all
````
 
The downloaded base image
(`/var/lib/libvirt/images/ubuntu-26.04-server-cloudimg-amd64.img`) is left in
place so re-runs don't re-download it. Delete it too if you want a truly
clean slate:
 
````fish
sudo rm -f /var/lib/libvirt/images/ubuntu-26.04-server-cloudimg-amd64.img
````
 
Then re-run `./create-vm.sh`.

## 3. Install UniFi OS Server inside the VM

`ssh pceiley@192.168.5.6` - the MOTD repeats this, but in short:

1. Grab the current "UniFi OS Server for Linux (x64)" download link from
   <https://ui.com/download/software/unifi-os-server> (right-click → copy link).
2. ```bash
   wget '<link>' -O unifi-os-server-installer
   chmod +x unifi-os-server-installer
   sudo ./unifi-os-server-installer
   ```
3. The installer is interactive - confirm the version prompt, it'll create a
   `uosserver` system user, set up the podman container, and a
   `uosserver.service` systemd unit.
4. Browse to `https://<vm-ip>:11443` to run first-run setup.

Useful day-to-day commands inside the VM: `sudo uosserver status|start|stop|shell`.

## 4. Open ports

UniFi OS Server's web UI is on **11443** (not 8443 like the old Network
Application). Inside the VM, allow it through ufw if enabled:

```bash
sudo ufw allow 11443/tcp
sudo ufw allow 8080/tcp        # device inform
sudo ufw allow 3478/udp        # STUN
sudo ufw allow 10001/udp       # AP discovery
sudo ufw allow 1900/udp        # SSDP discovery
```

Since the VM sits on `br0` with its own LAN IP, no port-forwarding or NAT
rules are needed on superslice itself.

## 5. Decommissioning the old controller

Once devices have been migrated to the new UniFi OS Server controller and
you're happy, `hosts/superslice/services/unifi.nix` and
`container-unifi.nix` can be deleted entirely (they're already commented out
of `default.nix`'s imports).

## Notes / gotchas

- Don't clone this VM for a second site - cloned UniFi OS Server instances
  share remote-access tokens with Site Manager/Fabrics and will misbehave.
  Spin up a fresh VM per site instead.
- If you're migrating an existing UniFi Network Application backup into
  UniFi OS Server, double-check the controller versions line up - restoring
  a backup from a *newer* Network App version than what ships in UniFi OS
  Server will be rejected.
- UniFi OS Server has its own auto-update timer (`uosserver-updater.service`)
  - disable/pin if you want manual control over upgrades.

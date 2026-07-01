# libvirtd + bridged networking, so VM guests sit directly on the
# 192.168.5.0/24 LAN (needed for UniFi OS Server's L2 device discovery/adoption).
#
# This replaces the static-on-eno1 setup with a bridge (br0):
#   eno1 -> enslaved to br0, no IP of its own
#   br0  -> carries the host's 192.168.5.5/24 address (as eno1 did before)
#   VMs  -> get a libvirt "bridge" interface attached to br0, i.e. real LAN IPs

{ pkgs, ... }:

{
  ##############################################################
  # Bridged networking (systemd-networkd)
  ##############################################################

  systemd.network.netdevs."10-br0" = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br0";
    };
  };

  # eno1 becomes a bridge port - no IP config of its own
  systemd.network.networks."10-eno1" = {
    matchConfig.Name = "eno1";
    networkConfig.Bridge = "br0";
    linkConfig.RequiredForOnline = "carrier";
  };

  # Workaround for a known e1000e TX hang ("Detected Hardware Unit Hang")
  # triggered by bridging eno1 into br0 above. TSO/GSO/GRO offload + bridging
  # is the most common reproduction case for this long-standing e1000e driver
  # bug; disabling those offloads avoids it at a small CPU/throughput cost
  # (negligible on a gigabit link). Re-applies whenever eno1 reappears,
  # including after the driver's own reset-on-hang recovery.
  systemd.services.eno1-offload-workaround = {
    description = "Disable TSO/GSO/GRO on eno1 to work around e1000e TX hangs under bridging";
    wantedBy = [ "network-pre.target" ];
    before = [ "network-pre.target" ];
    bindsTo = [ "sys-subsystem-net-devices-eno1.device" ];
    after = [ "sys-subsystem-net-devices-eno1.device" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.ethtool}/bin/ethtool -K eno1 tso off gso off gro off";
    };
  };

  # br0 takes over the host's previous static config
  systemd.network.networks."20-br0" = {
    matchConfig.Name = "br0";
    networkConfig.IPv6AcceptRA = true;
    address = [ "192.168.5.5/24" ];
    gateway = [ "192.168.5.254" ];
    dns = [ "192.168.5.254" ];

    # make the routes on this interface a dependency for network-online.target
    linkConfig.RequiredForOnline = "routable";
  };

  ##############################################################
  # libvirtd
  ##############################################################

  virtualisation.libvirtd = {
    enable = true;

    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };

    # Allow guests to attach directly to br0 via <source bridge="br0"/>
    allowedBridges = [ "br0" "virbr0" ];
  };

  # pceiley is already added to the "libvirtd" group via
  # hosts/common/users/pceiley (ifTheyExist), once this module is imported.

  ##############################################################
  # Helper tooling for managing VMs from the CLI
  ##############################################################

  environment.systemPackages = with pkgs; [
    virtiofsd         # virtio-fs support
    virt-manager
    xorriso
    qemu_kvm
  ];

  # NB: NixOS's nftables-based firewall filters traffic destined *to* the
  # host (INPUT) and routed traffic (FORWARD). Plain L2 bridging on br0
  # bypasses both unless the br_netfilter kernel module is loaded, which it
  # isn't by default - so VM <-> LAN traffic should just work without any
  # extra firewall rules here.
}

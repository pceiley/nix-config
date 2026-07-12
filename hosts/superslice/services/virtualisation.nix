# libvirtd for the halloumi (UniFi OS Server) VM.
#
# superslice itself now lives on vlan6_server (192.168.6.4) - it no longer
# shares a VLAN with halloumi, which stays on vlan5_management
# (192.168.5.6) via a tagged VLAN sub-interface (eno1.5) and a macvtap
# ("direct") interface, rather than the flat bridge (br0) this used to be.

{ pkgs, ... }:

{
  ##############################################################
  # VLAN 5 sub-interface for halloumi (systemd-networkd)
  ##############################################################

  systemd.network.netdevs."25-eno1.5" = {
    netdevConfig = {
      Kind = "vlan";
      Name = "eno1.5";
    };
    vlanConfig.Id = 5;
  };

  systemd.network.networks."10-eno1" = {
    matchConfig.Name = "eno1";
    networkConfig = {
      IPv6AcceptRA = true;
      VLAN = [ "eno1.5" ];
    };
    address = [ "192.168.6.4/24" ];
    gateway = [ "192.168.6.254" ];
    dns = [ "192.168.6.254" ];
    linkConfig.RequiredForOnline = "routable";
  };

  # Carries only halloumi's tagged VLAN 5 traffic - no IP of its own, just
  # needs to be up for libvirt's macvtap device to attach to.
  systemd.network.networks."15-eno1.5" = {
    matchConfig.Name = "eno1.5";
    networkConfig.LinkLocalAddressing = "no";
    linkConfig.RequiredForOnline = "no";
  };

  # Workaround for a known e1000e TX hang ("Detected Hardware Unit Hang")
  # originally triggered by bridging eno1 into br0. eno1 isn't bridged any
  # more, but macvtap still puts the NIC into a similar multi-MAC receive
  # mode for halloumi's traffic, so keeping this as cheap insurance rather
  # than assuming the switch away from br0 alone fixes it.
  systemd.services.eno1-offload-workaround = {
    description = "Disable TSO/GSO/GRO on eno1 to work around e1000e TX hangs";
    wantedBy = [ "network-pre.target" ];
    before = [ "network-pre.target" ];
    bindsTo = [ "sys-subsystem-net-devices-eno1.device" ];
    after = [ "sys-subsystem-net-devices-eno1.device" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.ethtool}/bin/ethtool -K eno1 tso off gso off gro off";
    };
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
}

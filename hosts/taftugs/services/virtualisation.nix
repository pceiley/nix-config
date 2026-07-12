# libvirtd for the halloumi (UniFi OS Server) VM.
#
# taftugs stays on vlan6_server itself. halloumi's VLAN 5 traffic rides the
# tagged eno1.5 sub-interface (see default.nix) straight into a macvtap
# ("direct") interface - no Linux bridge, since taftugs and halloumi are on
# different subnets regardless and were never going to talk over pure L2.

{ pkgs, ... }:

{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };

  # pceiley picks up the libvirtd group automatically via the existing
  # ifTheyExist wiring in hosts/common/users/pceiley.

  environment.systemPackages = with pkgs; [
    virtiofsd
    virt-manager
    xorriso
    qemu_kvm
  ];
}

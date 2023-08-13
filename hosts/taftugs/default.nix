# HP Elitedesk 800 G4 SFF
{ inputs, lib, ... }:
{
  imports = [
    ../common
    ../common/users/pceiley

    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "nvme" "usbhid" "uas" "sd_mod" ];
    kernelModules = [ "kvm-intel" ];
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.configurationLimit = 10;
      systemd-boot.enable = true;
      systemd-boot.memtest86.enable = true;
      timeout = 10;
    };
  };

  networking = {
    hostName = "taftugs";
    useDHCP = true;
  };
  
  zramSwap.enable = true;

  system.stateVersion = "22.05";
  
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

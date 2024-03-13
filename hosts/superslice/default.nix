# Intel NUC 8i5
{ inputs, lib, pkgs, config, ... }: {
  imports = [
    ../common

    ../common/users/pceiley
    ../common/users/cceiley

    #./services/container-unifi.nix
    ./services/unifi.nix

    inputs.nixos-hardware.nixosModules.common-cpu-intel
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
      #systemd-boot.memtest86.enable = true;
      timeout = 10;
    };
  };

  fileSystems."/" =
    { device = "/dev/disk/by-label/nixos";
      fsType = "xfs";
      options = [ "defaults" "noatime" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-label/boot";
      fsType = "vfat";
    };
  
  #swapDevices = [{
  #  device = "/swap";
  #  size = 2048;
  #}];

  zramSwap.enable = true;

  services.thermald.enable = lib.mkDefault true;

  networking = {
    hostName = "superslice";
    defaultGateway = "192.168.5.254";
    interfaces.eno1.ipv4.addresses = [{
      address = "192.168.5.5";
      prefixLength = 24;
    }];
    nameservers = [ "192.168.5.254" ];
    useDHCP = lib.mkForce false;
  };

  system.stateVersion = "23.11";
  
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

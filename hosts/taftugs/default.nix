# HP Elitedesk 800 G4 SFF
{ inputs, lib, ... }: {
  imports = [
    ../common
    ../common/users/pceiley
    ../common/users/cceiley

    #./services/nfs-cheddar.nix
    #./services/samba.nix

    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "nvme" "usbhid" "uas" "sd_mod" ];
    kernelModules = [ "kvm-intel" ];
    
    supportedFilesystems = [ "zfs" ];
    zfs.forceImportRoot = false;
    zfs.extraPools = [ "data" ];

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
  
  swapDevices = [{
    device = "/swap";
    size = 2048;
  }];

  #zramSwap.enable = true;

  networking = {
    hostName = "taftugs";
    hostId = "8ec040f1";
    defaultGateway = "192.168.10.254";
    interfaces.eno1.ipv4.addresses = [{
      address = "192.168.10.3";
      prefixLength = 24;
    }];
    nameservers = [ "192.168.10.254" ];
    useDHCP = lib.mkForce false;
  };

  system.stateVersion = "22.05";
  
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

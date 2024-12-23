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
  
  swapDevices = [{
    device = "/swap";
    size = 32*1024;
  }];

  #zramSwap.enable = true;

  services.thermald.enable = lib.mkDefault true;

  networking = {
    hostName = "superslice";
    useDHCP = lib.mkForce false;
  };

  systemd.network.enable = true;

  systemd.network.networks."10-eno1" = {
    matchConfig.Name = "eno1";
    networkConfig = {
      IPv6AcceptRA = true;
    };
    address = [ "192.168.5.5/24" ];
    gateway = [ "192.168.5.254" ];
    dns = [ "192.168.5.254" ];

    # make the routes on this interface a dependency for network-online.target
    linkConfig.RequiredForOnline = "routable";
  };


  system.stateVersion = "23.11";
  
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

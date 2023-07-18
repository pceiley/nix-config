# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/9b0d79e4-704b-4bc7-834d-f2dd8aa4b638";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/05DA-D06E";
      fsType = "vfat";
    };

  fileSystems."/mnt/backupusb" =
    { device = "/dev/disk/by-uuid/2f40a937-359e-49b8-8563-b66f679f17f8";
      fsType = "ext4";
      options = [ "nofail,x-systemd.device-timeout=1ms,noauto,x-systemd.automount" ];
    };

  swapDevices = [ ];

  zramSwap.enable = true;

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault false;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
  
  networking.interfaces.eno1.ipv4.addresses = [ {
    address = "192.168.10.5";
    prefixLength = 24;
  } ];

  networking.defaultGateway = "192.168.10.254";
  networking.nameservers = [ "192.168.10.254" ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

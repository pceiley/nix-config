# HP Elitedesk 800 G4 SFF
{ inputs, lib, pkgs, config, ... }: {
  imports = [
    ../common

    ../common/users/pceiley
    ../common/users/cceiley

    ../common/modules/qbittorrent.nix

    #./services/nfs-cheddar.nix
    ./services/jellyfin.nix
    ./services/nextcloud.nix
    ./services/paperless.nix
    ./services/plex.nix
    ./services/qbittorrent.nix
    ./services/restic.nix
    ./services/rp.nix
    ./services/samba.nix
    #./services/unifi.nix
    ./services/wireguard-wg0.nix

    inputs.nixos-hardware.nixosModules.common-cpu-intel
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
  
  #swapDevices = [{
  #  device = "/swap";
  #  size = 2048;
  #}];

  fileSystems."/mnt/usb-backup" =
    { device = "/dev/disk/by-uuid/2f40a937-359e-49b8-8563-b66f679f17f8";
      fsType = "ext4";
      options = [ "nofail,x-systemd.device-timeout=1ms,noauto,x-systemd.automount" ];
    };

  zramSwap.enable = true;

  # ZFS Configuration - I might move this out of here
  services.zfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };

  # Enable ZFS email notifications
  # ref https://nixos.wiki/wiki/ZFS
  services.zfs.zed.settings = {
    ZED_DEBUG_LOG = "/tmp/zed.debug.log";
    ZED_EMAIL_ADDR = [ "root" ];
    ZED_EMAIL_PROG = "${pkgs.msmtp}/bin/msmtp";
    ZED_EMAIL_OPTS = "@ADDRESS@";

    ZED_NOTIFY_INTERVAL_SECS = 3600;
    ZED_NOTIFY_VERBOSE = true;

    ZED_USE_ENCLOSURE_LEDS = true;
    ZED_SCRUB_AFTER_RESILVER = true;
  };
  # this option does not work; will return error
  services.zfs.zed.enableMail = false;

  # Tailscale
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "server";

  # ACME
  # LetsEncrypt wildcard certificate for *.purecheese.roastlan.net
  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@roastlan.net";
    certs."pc.roastlan.net" = {
      domain = "*.pc.roastlan.net";
      dnsProvider = "cloudflare";
      credentialsFile = "/persist/secrets/acme.txt";
      group = config.services.nginx.group;
    };
  };

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

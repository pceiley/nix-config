# HP Elitedesk 800 G4 SFF
{ inputs, lib, pkgs, config, ... }: {
  imports = [
    ../common

    ../common/users/pceiley
    ../common/users/cceiley

    #../common/modules/qbittorrent.nix

    ./services/actual.nix
    #./services/couchdb.nix
    ./services/jellyfin.nix
    ./services/mealie.nix
    #./services/nextcloud.nix
    ./services/nginx.nix
    ./services/paperless.nix
    #./services/plex.nix
    ./services/qbittorrent.nix
    ./services/restic.nix
    ./services/sabnzbd.nix
    ./services/samba.nix
    #./services/search.nix
    ./services/wireguard-wg0.nix

    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.sops-nix.nixosModules.sops
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
  services.zfs.zed.enableMail = true;
  services.zfs.zed.settings = {
    ZED_EMAIL_ADDR = [ "root" ];
    ZED_NOTIFY_VERBOSE = true;
  };

  # Tailscale
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "server";
  #services.tailscale.package = pkgs.unstable.tailscale;

  # ACME
  # LetsEncrypt wildcard certificate for *.p.ceiley.net
  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@ceiley.net";

    certs."p.ceiley.net" = {
      domain = "*.p.ceiley.net";
      dnsProvider = "cloudflare";
      credentialsFile = config.sops.secrets.cloudflare_credentials.path;
      group = config.services.nginx.group;
    };
  };

  networking = {
    hostName = "taftugs";
    hostId = "8ec040f1";
    # Should use systemd.network over networking.interfaces as better supported
    # as per https://nixos.wiki/wiki/Systemd-networkd
    #defaultGateway = "192.168.10.254";
    #interfaces.eno1.ipv4.addresses = [{
    #  address = "192.168.10.3";
    #  prefixLength = 24;
    #}];
    #nameservers = [ "192.168.10.254" ];
    useDHCP = lib.mkForce false;
  };

  systemd.network.enable = true;

  systemd.network.networks."10-eno1" = {
    matchConfig.Name = "eno1";
    networkConfig = {
      IPv6AcceptRA = true;
    };
    address = [ "192.168.10.3/24" ];
    gateway = [ "192.168.10.254" ];
    dns = [ "192.168.10.254" ];

    # make the routes on this interface a dependency for network-online.target
    linkConfig.RequiredForOnline = "routable";
  };

  system.stateVersion = "22.05";
  
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  #https://wiki.nixos.org/wiki/Accelerated_Video_Playback
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # For Broadwell (2014) or newer processors. LIBVA_DRIVER_NAME=iHD
    ];
  };
  environment.sessionVariables = { LIBVA_DRIVER_NAME = "iHD"; };

  # https://github.com/Mic92/sops-nix?tab=readme-ov-file#deploy-example
  sops = {
    age = {
      # This will automatically import SSH keys as age keys
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      # This is using an age key that is expected to already be in the filesystem
      keyFile = "/var/lib/sops-nix/key.txt";
      # This will generate a new key if the key specified above does not exist
      generateKey = true;
    };
    defaultSopsFile = ../../secrets/secrets.yaml;
  };

  sops.secrets.cloudflare_credentials = {
    owner = "acme";
    group = "acme";
    mode = "0440";
  };

}

# HP Elitedesk 800 G4 SFF
{ inputs, lib, pkgs, config, ... }: {
  imports = [
    ../common
    ../common/users/pceiley
    ../common/users/cceiley

    ../common/modules/monitoring-exporters.nix
    ../common/modules/restic-metrics.nix

    # Services
    ./services/actual.nix
    #./services/immich.nix
    ./services/jellyfin.nix
    ./services/kanidm.nix
    ./services/mealie.nix
    #./services/nextcloud.nix
    ./services/nginx.nix
    ./services/paperless.nix
    ./services/papra.nix
    ./services/postgresql.nix
    ./services/oauth2-proxy.nix
    #./services/plex.nix
    ./services/qbittorrent.nix
    ./services/restic.nix
    ./services/restic-recv.nix
    #./services/sabnzbd.nix
    ./services/samba.nix
    #./services/search.nix
    ./services/mullvad-vpn.nix

    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.sops-nix.nixosModules.sops
    inputs.vpn-confinement.nixosModules.default
  ];

  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "nvme" "usbhid" "uas" "sd_mod" ];
    kernelModules = [ "kvm-intel" ];
    # Required for low power encoding
    kernelParams = [ "i915.enable_guc=2" ];

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

  fileSystems."/mnt/usb-backup" = {
    device = "/dev/disk/by-uuid/2f40a937-359e-49b8-8563-b66f679f17f8";
    fsType = "ext4";
    options = [ "nofail" "noauto" "x-systemd.automount" "x-systemd.device-timeout=5s" ];
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
  #services.tailscale.enable = true;
  #services.tailscale.useRoutingFeatures = "server";
  #services.tailscale.package = pkgs.unstable.tailscale;

  networking = {
    hostName = "taftugs";
    hostId = "8ec040f1";
    # nftables backend, for the source-scoped exporter rule (VPN-Confinement coexists).
    nftables.enable = true;
    useDHCP = lib.mkForce false;
  };

  networking.hosts = {
      "192.168.6.3" = [ "taftugs" "taftugs.srv.roastlan.net" ];
      "192.168.6.4"  = [ "superslice" "superslice.srv.roastlan.net" ];
  };

  systemd.network.enable = true;

  systemd.network.networks."10-eno1" = {
    matchConfig.Name = "eno1";
    networkConfig = {
      IPv6AcceptRA = true;
    };
    address = [ "192.168.6.3/24" ];
    gateway = [ "192.168.6.254" ];
    dns = [ "192.168.6.254" ];

    # make the routes on this interface a dependency for network-online.target
    linkConfig.RequiredForOnline = "routable";
  };

  # iperf3
  networking.firewall.allowedTCPPorts = [ 5201 ];
  networking.firewall.allowedUDPPorts = [ 5201 ];

  system.stateVersion = "22.05";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  #https://wiki.nixos.org/wiki/Accelerated_Video_Playback
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-ocl # Generic OpenCL support
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

}

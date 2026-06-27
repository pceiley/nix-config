# Intel NUC 8i5
{ inputs, lib, pkgs, config, ... }: {
  imports = [
    ../common

    ../common/users/pceiley
    ../common/users/cceiley

    #./services/container-unifi.nix
    #./services/unifi.nix
    ./services/kanidm.nix
    ./services/monitoring.nix
    ./services/restic.nix
    ./services/virtualisation.nix

    ../common/modules/monitoring-exporters.nix

    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.sops-nix.nixosModules.sops
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
    # nftables backend, for the source-scoped exporter rule (libvirt coexists).
    nftables.enable = true;
  };
  networking.hosts = {
      "192.168.10.3" = [ "taftugs" "taftugs.srv.roastlan.net" ];
      "192.168.5.5"  = [ "superslice" "superslice.srv.roastlan.net" ];
  };

  systemd.network.enable = true;

  #
  # This is now handled by the bridge configured in services/virtualisation.nix
  #
  # systemd.network.networks."10-eno1" = {
  #   matchConfig.Name = "eno1";
  #   networkConfig = {
  #     IPv6AcceptRA = true;
  #   };
  #   address = [ "192.168.5.5/24" ];
  #   gateway = [ "192.168.5.254" ];
  #   dns = [ "192.168.5.254" ];

  #   # make the routes on this interface a dependency for network-online.target
  #   linkConfig.RequiredForOnline = "routable";
  # };


  system.stateVersion = "23.11";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

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

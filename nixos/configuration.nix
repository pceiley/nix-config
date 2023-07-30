# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)

{ inputs, lib, config, pkgs, ... }: {
  # You can import other NixOS modules here
  imports = [
    # If you want to use modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # You can also split up your configuration and import pieces of it here:
    # ./users.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix
   
    # Restic Backups
    ./restic-config.nix

    # Containers
    ./containers-config.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # If you want to use overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })

      # When applied, the unstable nixpkgs set (declared in the flake inputs) will
      # be accessible through 'pkgs.unstable'
      (final: prev: {
        unstable = import inputs.nixpkgs-unstable {
          system = final.system;
          config.allowUnfree = true;
        };
      })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  nix = {
    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Deduplicate and optimize nix store
      auto-optimise-store = true;
    };
  };

  # Hostname
  networking.hostName = "superslice";

  # Boot Loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Time zone
  time.timeZone = "Australia/Sydney";

  # Internationalisation properties.
  i18n.defaultLocale = "en_AU.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  zramSwap.enable = true;

  # NIC configuration
  networking.useDHCP = lib.mkDefault false;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
  networking.interfaces.eno1.ipv4.addresses = [ {
    address = "192.168.10.5";
    prefixLength = 24;
  } ];
  networking.defaultGateway = "192.168.10.254";
  networking.nameservers = [ "192.168.10.254" ];

  # Custom filesystem config
  systemd.tmpfiles.rules = [
    "d /secrets 0750 root wheel"
  ];

  # Set up users
  users.users = {
    pceiley = {
      # If you do, you can skip setting a root password by passing '--no-root-passwd' to nixos-install.
      initialPassword = "Chang3m3";
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCu6Wma9pEEdK1znwGxUowDZfSolZQjchG2YYuL2aQLO8qxHAqJV5LhBF2wIhnWOBX+9ta4oSdQ7edGh8gbqFH85z/bpnzkBVs6xrFIkuYWDG+eomzpiquWZLrUZWFdYQmkXeZ5oR24IeYHqh4jZJD0xOqnPxy+QivRp9+vcw+OuwWSIQjJGrJGNElbZ5zAXGN55zWx3mNBx9KLpElKuVblldIu/O7ds2R/Gebc7zMGm7QHLKCZ8V7d0B3R/LdfEemDiSrimCb69Fwn0blN5g1NuT4xOUzSIH1Fc9Bi9dXFgGvQrl1MVEeE4FTUzuwP1+sy5D3bT2wVWN2ecvXBrtY8fyzok/R9AsKrL81NqJjkFxtOsmFEDwNnzuJ4D5IKAsuZvx3Zhm3pyi3Oi9DSsGrsLximqWL1rZ5lO7nzUZEAvrUE78GNLTNFN8Cb9P9Oe1Vy9uUN/g/RoW6xZGTYy6kscaQglfivr9HQgGljiWRqikn1PiDr0dgSYcKzHQde1Ts="
      ];
      extraGroups = [ "wheel" ];
      shell = pkgs.fish;
    };
  };

  # Set up groups
  users.groups = {
    media = {
      members = [ "pceiley" "plex" ];
      gid = 800;
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    cifs-utils
    git
    htop
    micro
    podman
    restic
    screen
    vim
    wget
  ];

  # CIFS mounts
  fileSystems."/net/share" = {
      device = "//192.168.10.2/share";
      fsType = "cifs";
      options = ["x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,uid=root,gid=wheel,dir_mode=0750,file_mode=0640,credentials=/secrets/smb.txt"];
  };
  fileSystems."/net/media" = {
      device = "//192.168.10.2/media";
      fsType = "cifs";
      options = ["x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,uid=root,gid=media,dir_mode=0775,file_mode=0664,credentials=/secrets/smb.txt"];
  };
  fileSystems."/net/backup" = {
      device = "//192.168.10.2/backup";
      fsType = "cifs";
      options = ["x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,uid=root,gid=wheel,dir_mode=0750,file_mode=0640,credentials=/secrets/smb.txt"];
  };

  # Fish Shell
  programs.fish.enable = true;

  # Email
  environment.etc = {
    "aliases" = {
      text = ''
        root: pgceiley@gmail.com
        pceiley: pgceiley@gmail.com
      '';
      mode = "0644";
    };
  };

  programs.msmtp = {
    enable = true; 
    accounts = { 
      default = {
        auth = true;
        tls = true;
        # try setting `tls_starttls` to `false` if sendmail hangs
        from = "pgceiley@gmail.com";
        host = "smtp.gmail.com";
        user = "pgceiley@gmail.com";
        passwordeval = "cat /secrets/smtp.txt";
      };
    };
    defaults = {
      aliases = "/etc/aliases";
    };
  };

  # SSH server
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
    #passwordAuthentication = false;
  };

  # Plex
  services.plex = {
    enable = true;
    openFirewall = true;
    package = pkgs.unstable.plex;
  };

  # Unifi controller
  services.unifi = {
    enable = true;
    openFirewall = true;
    unifiPackage = pkgs.unifi;
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 8443 ];
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  # Enable the use of containers
  virtualisation.containers.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.05";
}

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

  # Custom filesystem config
  systemd.tmpfiles.rules = [
    "d /secrets 0750 root wheel"
  ];

  users.users = {
    pceiley = {
      # If you do, you can skip setting a root password by passing '--no-root-passwd' to nixos-install.
      initialPassword = "Chang3m3";
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCu6Wma9pEEdK1znwGxUowDZfSolZQjchG2YYuL2aQLO8qxHAqJV5LhBF2wIhnWOBX+9ta4oSdQ7edGh8gbqFH85z/bpnzkBVs6xrFIkuYWDG+eomzpiquWZLrUZWFdYQmkXeZ5oR24IeYHqh4jZJD0xOqnPxy+QivRp9+vcw+OuwWSIQjJGrJGNElbZ5zAXGN55zWx3mNBx9KLpElKuVblldIu/O7ds2R/Gebc7zMGm7QHLKCZ8V7d0B3R/LdfEemDiSrimCb69Fwn0blN5g1NuT4xOUzSIH1Fc9Bi9dXFgGvQrl1MVEeE4FTUzuwP1+sy5D3bT2wVWN2ecvXBrtY8fyzok/R9AsKrL81NqJjkFxtOsmFEDwNnzuJ4D5IKAsuZvx3Zhm3pyi3Oi9DSsGrsLximqWL1rZ5lO7nzUZEAvrUE78GNLTNFN8Cb9P9Oe1Vy9uUN/g/RoW6xZGTYy6kscaQglfivr9HQgGljiWRqikn1PiDr0dgSYcKzHQde1Ts="
      ];
      extraGroups = [ "wheel" ];
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    cifs-utils
    git
    htop
    micro
    screen
    vim
    wget
  ];

  # CIFS mounts
  fileSystems."/net/share" = {
      device = "//192.168.10.2/share";
      fsType = "cifs";
      options = ["x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,credentials=/secrets/smb.txt"];
  };
  fileSystems."/net/media" = {
      device = "//192.168.10.2/media";
      fsType = "cifs";
      options = ["x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,credentials=/secrets/smb.txt"];
  };
  fileSystems."/net/backup" = {
      device = "//192.168.10.2/backup";
      fsType = "cifs";
      options = ["x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,credentials=/secrets/smb.txt"];
  };

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

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.05";
}

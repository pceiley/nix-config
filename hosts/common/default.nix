# This file (and the global directory) holds config that i use on all hosts
{ inputs, outputs, pkgs, lib, ... }: {
  imports = [
    ./acme.nix
    ./openssh.nix
    ./smtp.nix
  ];

  nixpkgs = {
    overlays = [
      (final: prev: {

        # Make unstable nixpkgs accessible through 'pkgs.unstable'
        unstable = import inputs.nixpkgs-unstable {
          system = final.stdenv.hostPlatform.system;
          config.allowUnfree = true;
        };

      })
    ];

    # Configure your nixpkgs instance
    config = {
      allowUnfree = true;
    };
  };

  hardware.enableRedistributableFirmware = true;

  # Locale
  time.timeZone = "Australia/Sydney";
  i18n.defaultLocale = "en_AU.UTF-8";

  # Console
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Nix
  nix = {
    settings = {
      #trusted-users = [ "root" "@wheel" ];
      auto-optimise-store = lib.mkDefault false;
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
      flake-registry = ""; # Disable global flake registry
    };
    gc = {
      automatic = true;
      dates = "weekly";
      # Delete older generations too
      options = "--delete-older-than 10d";
    };
    # Store optimisation (hardlinking dedupe) moved off the build path and onto
    # a schedule instead, since auto-optimise-store hashes every file added to
    # the store on every build/switch.
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };

    # Add each flake input as a registry
    # To make nix3 commands consistent with the flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # Add nixpkgs input to NIX_PATH
    # This lets nix2 commands still use <nixpkgs>
    nixPath = [ "nixpkgs=${inputs.nixpkgs.outPath}" ];
  };

  # Filesystem
  #systemd.tmpfiles.rules = [
  #  "d /secrets 0750 root wheel"
  #];

  # Environment
  environment = {
    systemPackages = (with pkgs; [
      age
      bottom
      dig
      ghostty.terminfo
      git
      htop
      just
      micro
      nh
      podman
      restic
      screen
      sops
      ssh-to-age
      tldr
      unzip
      vim
      wget
      yazi
      zellij
    ]) ++ (with pkgs.unstable; [
      yt-dlp
    ]);

    variables = {
      EDITOR = "vim";
      SYSTEMD_EDITOR = "vim";
      VISUAL = "vim";
    };
  };

  programs = {
    command-not-found.enable = false;

    fish = {
      enable = true;
      shellAbbrs = {
        nix-gc = "sudo nix-collect-garbage --delete-older-than 14d";
        rebuild-host = "sudo nixos-rebuild switch --flake $HOME/nix-config";
        rebuild-lock = "pushd $HOME/nix-config && nix flake lock --recreate-lock-file && popd";
      };
      shellAliases = {
        moon = "curl -s wttr.in/Moon";
        pubip = "curl -s ifconfig.me/ip";
        wttr = "curl -s wttr.in && curl -s v2.wttr.in";
        wttr-pan = "curl -s wttr.in/panania && curl -s v2.wttr.in/panania";
      };
    };

  };

}

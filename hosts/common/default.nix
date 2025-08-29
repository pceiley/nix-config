# This file (and the global directory) holds config that i use on all hosts
{ inputs, outputs, pkgs, lib, ... }: {
  imports = [
    ./openssh.nix
    ./smtp.nix
  ];

  nixpkgs = {
    overlays = [
      (final: prev: {

        # Make unstable nixpkgs accessible through 'pkgs.unstable'
        unstable = import inputs.nixpkgs-unstable {
          system = final.system;
          config.allowUnfree = true;
        };
       
        ## Workaround to manually pin the plex version
        #plex = prev.plex.overrideAttrs (oldAttrs: {
        #  version = "1.42.1.10060-4e8b05daf";
        #  src = prev.fetchurl {
        #    url = "https://downloads.plex.tv/plex-media-server-new/1.42.1.10060-4e8b05daf/debian/plexmediaserver_1.42.1.10060-4e8b05daf_amd64.deb";
        #    sha256 = "3a822dbc6d08a6050a959d099b30dcd96a8cb7266b94d085ecc0a750aa8197f4";
        #  };
        #});

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
      auto-optimise-store = lib.mkDefault true;
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
      #system-features = [ "kvm" "big-parallel" "nixos-test" ];
      flake-registry = ""; # Disable global flake registry
    };
    gc = {
      automatic = true;
      dates = "weekly";
      # Delete older generations too
      options = "--delete-older-than 10d";
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
    systemPackages = with pkgs; [
      age
      bottom
      dig
      git
      htop
      micro
      podman
      restic
      screen
      sops
      unzip
      vim
      wget
      zellij
    ];
    variables = {
      EDITOR = "vim";
      SYSTEMD_EDITOR = "vim";
      VISUAL = "vim";
    };
  };

  # Fish Shell
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
        wttr-bas = "curl -s wttr.in/basingstoke && curl -s v2.wttr.in/basingstoke";
      };
    };
  };

}

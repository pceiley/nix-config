# Plex

{ pkgs, ... }:

{
  services.plex = {
    enable = true;
    openFirewall = true;
    dataDir = "/srv/plex";
    package = pkgs.unstable.plex;

    # Keeping in case I need to override the version again
    #package = pkgs.plex.override {
    #  plexRaw = pkgs.plexRaw.overrideAttrs (_: {
    #    version = "1.42.1.10060-4e8b05daf";
    #    src = pkgs.fetchurl {
    #      url = "https://downloads.plex.tv/plex-media-server-new/1.42.1.10060-4e8b05daf/debian/plexmediaserver_1.42.1.10060-4e8b05daf_amd64.deb";
    #      sha256 = "3a822dbc6d08a6050a959d099b30dcd96a8cb7266b94d085ecc0a750aa8197f4";
    #    };
    #  });
    #};

    #package = pkgs.plex.overrideAttrs (old: {
    #  version = "1.42.1.10060-4e8b05daf";
    #  src = pkgs.fetchurl {
    #    url = "https://downloads.plex.tv/plex-media-server-new/1.42.1.10060-4e8b05daf/debian/plexmediaserver_1.42.1.10060-4e8b05daf_amd64.deb";
    #    sha256 = "3a822dbc6d08a6050a959d099b30dcd96a8cb7266b94d085ecc0a750aa8197f4";
    #  };
    #});

  };
}

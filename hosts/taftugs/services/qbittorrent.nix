# qBittorrent
#

{ pkgs, ... }:

let
  downloadDir = "/data/multimedia/downloads";
  incompleteDir = "/data/multimedia/incomplete";
in
{
  services.qbittorrent = {
    enable = true;
    # WebUI is exposed via the VPN namespace portMappings + accessibleFrom,
    # not via the host firewall (qBittorrent no longer listens on the host).
    openFirewall = false;
    #profileDir = "/srv/qbittorrent";
    package = pkgs.unstable.qbittorrent-nox;
    webuiPort = 58080;

    serverConfig = {
      BitTorrent.Session = {
        DefaultSavePath = downloadDir;
        TempPath = incompleteDir;
        TempPathEnabled = true;
        GlobalDLSpeedLimit = 40000;
        GlobalUPSpeedLimit = 1000;
        AlternativeGlobalDLSpeedLimit = 10000;
        AlternativeGlobalUPSpeedLimit = 500;
        GlobalMaxSeedingMinutes = 15;
      };
      Preferences.WebUI = {
        Address = "172.16.15.1";
        AuthSubnetWhitelistEnabled = true;
        AuthSubnetWhitelist = "172.16.15.0/24";
        HostHeaderValidation = false;
        CSRFProtection = false;
      };
      RSS = {
        Session.EnableProcessing = true;
        AutoDownloader.EnableProcessing = true;
        AutoDownloader.DownloadRepacks = true;
      };
    };
  };

  # Run qBittorrent inside the Mullvad VPN network namespace (all its traffic
  # egresses through wireguard; nothing else on the host is affected).
  systemd.services.qbittorrent = {
    vpnConfinement = {
      enable = true;
      vpnNamespace = "mullvad";
    };
    path = [ pkgs.python3 ];
    # create files 664 / dirs 775 (umask 002); with the setgid multimedia
    # parent dirs, completed downloads come out group-owned by multimedia and
    # group-writable at creation, and survive temp->save moves and WebUI
    # recategorisation (unlike a completion-hook chmod). app files under
    # /var/lib are group qbittorrent, whose group has no other members.'
    serviceConfig.UMask = "0002";
    # One-time cleanup for anything already downloaded:
    # sudo find /data/multimedia/downloads -type d -exec chmod 2775 {} +
    # sudo find /data/multimedia/downloads -type f -exec chmod 0664 {} +
  };

  # Allow qbittorrent to save files in the multimedia share
  users.users.qbittorrent.extraGroups = [ "multimedia" ];

  systemd.tmpfiles.rules = [
    "d ${downloadDir} 2775 qbittorrent multimedia -"
    "d ${incompleteDir} 2775 qbittorrent multimedia -"
  ];
}

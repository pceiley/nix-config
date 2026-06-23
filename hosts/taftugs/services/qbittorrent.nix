# qBittorrent service activation
#
# The shell script 'fixdlperms' is also created and should be added to the
# "Run external program on finished" section with the full path:
# /run/current-system/sw/bin/fixdlperms

{ pkgs, ... }:

let
  downloadDir = "/data/multimedia/downloads";
  fixDownloadPerms = pkgs.writeShellScriptBin "fixdlperms" ''
    # only touches the single completed torrent path qBittorrent passes as %F
    path="$1"
    if [ -d "$path" ]; then
      find "$path" -type d -exec chmod 2775 {} +
      find "$path" -type f -exec chmod 0664 {} +
    elif [ -e "$path" ]; then
      chmod 0664 "$path"
    fi
  '';
in
{
  services.qbittorrent = {
    enable = true;
    # WebUI is exposed via the VPN namespace portMappings + accessibleFrom,
    # not via the host firewall (qBittorrent no longer listens on the host).
    openFirewall = false;
    #profileDir = "/srv/qbittorrent";
    #package = pkgs.unstable.qbittorrent-nox;
    webuiPort = 58080;

    serverConfig = {
      BitTorrent.Session = {
        DefaultSavePath = downloadDir;
        TempPath = "/var/lib/qbittorrent/incomplete";
        GlobalDLSpeedLimit = 40000;
        GlobalUPSpeedLimit = 1000;
        AlternativeGlobalDLSpeedLimit = 10000;
        AlternativeGlobalUPSpeedLimit = 500;
        GlobalMaxSeedingMinutes = 15;
      };
      Preferences.WebUI = {
        Address = "192.168.15.1";
        AuthSubnetWhitelistEnabled = true;
        AuthSubnetWhitelist = "192.168.15.0/24";
        HostHeaderValidation = false;
      };
      RSS = {
        Session.EnableProcessing = true;
        AutoDownloader.EnableProcessing = true;
        AutoDownloader.DownloadRepacks = true;
      };
      AutoRun = {
        enabled = true;
        program = ''${fixDownloadPerms}/bin/fixdlperms "%F"'';
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
  };

  # Allow qbittorrent to save files in the multimedia share
  users.users.qbittorrent.extraGroups = [ "multimedia" ];

  systemd.tmpfiles.rules = [
    "d ${downloadDir} 2775 qbittorrent multimedia -"
  ];
}

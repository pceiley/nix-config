# Peter's restic backup configuration for purecheese
#

{ config, ... }:

let
  secretsFile = "/secrets/restic.txt";
  rcloneFile = "/secrets/rclone.conf";
  backupTarget = "/net/share";
  excludes = [
    "${backupTarget}/Google Photos"
    "${backupTarget}/Music/Old iTunes"
    "${backupTarget}/Software"
  ];
  retentionPolicy = [
    "--keep-daily 14"
    "--keep-weekly 16"
    "--keep-monthly 18"
    "--keep-yearly 3"
  ];
in
{
  services.restic.backups = {
    localbackup = {
      initialize = true;
      exclude = excludes;
      passwordFile = secretsFile;
      paths = [ backupTarget ];
      repository = "/mnt/backupusb/restic-purecheese";
      timerConfig = {
        OnCalendar = "00:30";
        #RandomizedDelaySec = "1h";
      };
      pruneOpts = retentionPolicy;
    };

    remotebackup = {
      initialize = true;
      exclude = excludes;
      passwordFile = secretsFile;
      paths = [ backupTarget ];
      repository = "rclone:onedrive:restic-purecheese";
      rcloneConfigFile = rcloneFile;
      timerConfig = {
        OnCalendar = "02:00";
        #RandomizedDelaySec = "1h";
      };
      pruneOpts = retentionPolicy;
    };
  };
}



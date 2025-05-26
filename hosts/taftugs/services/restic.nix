# Peter's restic backup configuration for purecheese
#

{ config, ... }:

let
  secretsFile = "/persist/secrets/restic.txt";
  rcloneFile = "/persist/secrets/rclone.conf";
  localRepo = "/mnt/usb-backup/restic-purecheese";
  remoteRepo = "rclone:onedrive:restic-purecheese";
  backupActual = "/var/lib/actual";
  backupTarget = "/data/family";
  backupPaperless = "/var/lib/paperless";
  backupOther = "/data/backup";
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
      exclude = excludes;
      passwordFile = secretsFile;
      paths = [ backupTarget backupOther backupPaperless backupActual ];
      repository = localRepo;
      timerConfig = {
        OnCalendar = "01:30";
        #RandomizedDelaySec = "1h";
      };
      pruneOpts = retentionPolicy;
    };

    remotebackup = {
      exclude = excludes;
      passwordFile = secretsFile;
      paths = [ backupTarget backupOther backupPaperless backupActual ];
      repository = remoteRepo;
      rcloneConfigFile = rcloneFile;
      timerConfig = {
        OnCalendar = "02:30";
        #RandomizedDelaySec = "1h";
      };
      pruneOpts = retentionPolicy;
    };
  };

  programs.fish.shellAliases = {
    restic_local_env = "sudo RESTIC_REPOSITORY=${localRepo} RESTIC_PASSWORD_FILE=${secretsFile} -i";
    restic_remote_env = "sudo RCLONE_CONFIG=${rcloneFile} RESTIC_REPOSITORY=${remoteRepo} RESTIC_PASSWORD_FILE=${secretsFile} -i";
  };
}



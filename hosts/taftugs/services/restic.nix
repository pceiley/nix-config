# Peter's restic backup configuration for purecheese
#

{ config, pkgs, ... }:

let
  secretsFile = config.sops.secrets.restic_password.path;
  rcloneFile = config.sops.secrets.rclone_conf.path;
  localRepo = "/mnt/usb-backup/restic-purecheese";
  remoteRepo = "rclone:onedrive:restic-purecheese";
  backupActual = "/var/lib/private/actual";
  backupImmich = "/data/immich";
  backupMealie = "/var/lib/private/mealie";
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
      paths = [ backupTarget backupOther backupPaperless backupActual backupImmich backupMealie ];
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
      paths = [ backupTarget backupOther backupPaperless backupActual backupMealie ];
      repository = remoteRepo;
      rcloneConfigFile = rcloneFile;
      timerConfig = {
        OnCalendar = "02:30";
        #RandomizedDelaySec = "1h";
      };
      pruneOpts = retentionPolicy;
    };
  };

  systemd.services.restic-backups-localbackup.unitConfig.RequiresMountsFor = [ "/mnt/usb-backup" ];
  systemd.services.restic-backups-localbackup.serviceConfig.ExecStartPre =
      "${pkgs.util-linux}/bin/mountpoint -q /mnt/usb-backup";

  programs.fish.shellAliases = {
    restic_local_env = "sudo RESTIC_REPOSITORY=${localRepo} RESTIC_PASSWORD_FILE=${secretsFile} -i";
    restic_remote_env = "sudo RCLONE_CONFIG=${rcloneFile} RESTIC_REPOSITORY=${remoteRepo} RESTIC_PASSWORD_FILE=${secretsFile} -i";
  };

  # restic backups run as root, so the default sops owner/mode (root:root 0400) is fine.
  sops.secrets.restic_password = { };
  sops.secrets.rclone_conf = { };
}

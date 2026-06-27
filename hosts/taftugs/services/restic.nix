# Peter's restic backup configuration for purecheese
#
# rclone/onedrive token handling: the rclone_conf sops secret is a COLD SEED
# only. onedrive refreshes oauth tokens into the config file, which can't happen
# on a read-only tmpfs secret, so the secret is copied once into a writable
# /var/lib/rclone-backup/rclone.conf that rclone maintains. To rotate or recover
# from invalid_grant: update the seed in sops, `sudo rm` the live copy, redeploy.

{ config, pkgs, ... }:

let
  secretsFile = config.sops.secrets.restic_password.path;
  rcloneSeed = config.sops.secrets.rclone_conf.path;    # cold seed, read-only on tmpfs
  rcloneLive = "/var/lib/rclone-backup/rclone.conf";    # writable copy rclone updates
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
  # seed the writable rclone config from the sops secret ONLY if no working copy
  # exists yet - never clobber a live (refreshed) token with the stale seed.
  seedRcloneCmd = ''
    ${pkgs.coreutils}/bin/install -d -m700 /var/lib/rclone-backup
    if [ ! -f ${rcloneLive} ]; then
      ${pkgs.coreutils}/bin/install -m600 ${rcloneSeed} ${rcloneLive}
    fi
  '';
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
      rcloneConfigFile = rcloneLive;        # writable copy, NOT the read-only secret
      backupPrepareCommand = seedRcloneCmd; # seed the writable config before each run
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
    restic_remote_env = "sudo RCLONE_CONFIG=${rcloneLive} RESTIC_REPOSITORY=${remoteRepo} RESTIC_PASSWORD_FILE=${secretsFile} -i";  };

  # restic backups run as root, so the default sops owner/mode (root:root 0400) is fine.
  sops.secrets.restic_password = { };
  sops.secrets.rclone_conf = { };
}

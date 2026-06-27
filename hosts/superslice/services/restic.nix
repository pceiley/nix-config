# Peter's restic backup configuration for superslice
#
# Backs up the kanidm online-backup dumps (consistent json exports, NOT the live
# db) plus the sops age identity. Two tiers mirroring taftugs: an sftp repo on
# taftugs's USB disk (local) and onedrive via rclone (offsite). restic runs as
# root and authenticates to taftugs with superslice's ssh host key.
#
# The local (USB) repo uses initialize = false on purpose: it must be created
# manually once, on the mounted disk, so a missing USB makes the backup fail
# loudly instead of initializing a repo on the wrong filesystem. The onedrive
# repo has no such risk, so it auto-initializes.
#
# rclone/onedrive token handling: onedrive uses short-lived oauth tokens that
# rclone must REWRITE into its config on every refresh. The sops secret renders
# read-only on tmpfs, so rclone can't persist refreshes there and the refresh-
# token chain eventually breaks (silent auth failure after weeks). So the sops
# secret is only a COLD SEED, copied once into a writable working copy under
# /var/lib that rclone can update and that survives reboots.
#
#   *** If onedrive auth fails with "invalid_grant" / the seed is stale: ***
#   The live working copy's refresh-token chain has broken (or you wiped it and
#   re-seeded from an expired sops token). To recover:
#     1. rclone config reconnect onedrive:   (against a fresh config; re-auth)
#     2. update the rclone_conf sops secret with the new token
#     3. sudo rm /var/lib/rclone-backup/rclone.conf   (drop the stale live copy)
#     4. next backup re-seeds the writable copy from the refreshed secret
#   Always delete the live copy after rotating the seed, or the old token keeps
#   being used.
#
# NOTE: the sops age key is the DR root of trust and MUST also be escrowed
# offline - it cannot be recovered from a repo whose password is
# itself sops-encrypted.

{ config, pkgs, ... }:

let
  secretsFile = config.sops.secrets.restic_password.path;
  rcloneSeed = config.sops.secrets.rclone_conf.path;     # cold seed, read-only on tmpfs
  rcloneLive = "/var/lib/rclone-backup/rclone.conf";     # writable working copy rclone updates
  localRepo = "sftp:restic-recv@taftugs:/mnt/usb-backup/restic-superslice";
  remoteRepo = "rclone:onedrive:restic-superslice";
  hostKey = "/etc/ssh/ssh_host_ed25519_key";

  backupKanidm = "/var/lib/kanidm/backups";   # online-backup dumps, not the live db
  backupSops = "/var/lib/sops-nix/key.txt";

  retentionPolicy = [
    "--keep-daily 14"
    "--keep-weekly 16"
    "--keep-monthly 18"
    "--keep-yearly 3"
  ];

  sftpHelper = pkgs.writeShellScript "restic-sftp-taftugs" ''
    exec ssh -i ${hostKey} -o StrictHostKeyChecking=accept-new restic-recv@taftugs -s sftp
  '';

  # seed the writable rclone config from the sops secret ONLY if no working copy
  # exists yet - never clobber a live (refreshed) token with the stale seed.
  seedRcloneCmd = ''
    ${pkgs.coreutils}/bin/install -d -m700 /var/lib/rclone-backup
    if [ ! -f ${rcloneLive} ]; then
      ${pkgs.coreutils}/bin/install -m600 ${rcloneSeed} ${rcloneLive}
    fi
  '';

  paths = [ backupKanidm backupSops hostKey ];
in
{
  services.restic.backups = {
    localbackup = {
      inherit paths;
      initialize = false;            # init manually on the mounted USB; see runbook
      passwordFile = secretsFile;
      repository = localRepo;
      extraOptions = [ "sftp.command=${sftpHelper}" ];
      timerConfig = {
        OnCalendar = "01:00";
      };
      pruneOpts = retentionPolicy;
    };

    remotebackup = {
      inherit paths;
      initialize = true;             # onedrive has no wrong-disk risk
      passwordFile = secretsFile;
      repository = remoteRepo;
      rcloneConfigFile = rcloneLive; # writable copy, NOT the read-only secret
      # seed the writable rclone config before each remote backup runs.
      backupPrepareCommand = seedRcloneCmd;
      timerConfig = {
        OnCalendar = "03:30";
      };
      pruneOpts = retentionPolicy;
    };
  };

  programs.fish.shellAliases = {
    # browse the local repo from superslice (note the -o for the sftp transport):
    restic_local_env = "sudo restic -o sftp.command=${sftpHelper} -r ${localRepo} -p ${secretsFile}";    # remote browse uses the LIVE writable config, same as the backup job:
    restic_remote_env = "sudo RCLONE_CONFIG=${rcloneLive} RESTIC_REPOSITORY=${remoteRepo} RESTIC_PASSWORD_FILE=${secretsFile} -i";
  };

  # restic backups run as root, so the default sops owner/mode (root:root 0400) is fine.
  sops.secrets.restic_password = { };
  sops.secrets.rclone_conf = { };
}

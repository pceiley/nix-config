# Peter's restic backup configuration for purecheese
#
# rclone/onedrive token handling: the rclone_conf sops secret is a COLD SEED
# only. onedrive refreshes oauth tokens into the config file, which can't happen
# on a read-only tmpfs secret, so the secret is copied once into a writable
# /var/lib/rclone-backup/rclone.conf that rclone maintains. To rotate or recover
# from invalid_grant: update the seed in sops, `sudo rm` the live copy, redeploy.
#
# Scheduling model: nightly jobs only run `restic backup` (fast, no repack).
# The expensive operations - retention/forget, prune (repack) and integrity
# `check` - are pulled out onto a weekly maintenance timer per repo so the
# nightly runs stay quick and, for OneDrive, cheap on bandwidth/API calls.

{ config, pkgs, lib, ... }:

let
  secretsFile = config.sops.secrets.restic_password.path;
  rcloneSeed = config.sops.secrets.rclone_conf.path;    # cold seed, read-only on tmpfs
  rcloneLive = "/var/lib/rclone-backup/rclone.conf";    # writable copy rclone updates
  localRepo = "/mnt/usb-backup/restic-purecheese";
  remoteRepo = "rclone:onedrive:restic-purecheese";

  familyPath = "/data/family";
  otherPath = "/data/backup";
  paperlessPath = "/var/lib/paperless";
  actualPath = "/var/lib/private/actual";
  mealiePath = "/var/lib/private/mealie";
  immichPath = "/data/immich";
  # Papra spans two locations: the sqlite DB + ingestion folder under
  # /var/lib/papra (StateDirectory; static papra user, so NOT /var/lib/private),
  # and the document blobs on the dedicated ZFS dataset at /data/papra.
  papraStatePath = "/var/lib/papra";
  papraDocsPath = "/data/papra";

  # Backed up to both repos. Immich is local-only (too large for the OneDrive
  # quota), so it's appended to the local paths rather than living here.
  commonPaths = [
    familyPath otherPath paperlessPath
    actualPath mealiePath
    papraStatePath papraDocsPath
  ];

  excludes = [
    "${familyPath}/Google Photos"
    "${familyPath}/Music/Old iTunes"
    "${familyPath}/Software"
  ];
  retentionPolicy = [
    "--keep-daily 14"
    "--keep-weekly 16"
    "--keep-monthly 18"
    "--keep-yearly 3"
  ];

  # shared by both jobs; kept in one place so excludes/password can't drift
  # apart between local and remote. Retention lives with the weekly maintenance
  # jobs below, not here, since nightly runs no longer forget/prune.
  commonOpts = {
    exclude = excludes;
    passwordFile = secretsFile;
  };

  # seed the writable rclone config from the sops secret ONLY if no working copy
  # exists yet - never clobber a live (refreshed) token with the stale seed.
  seedRcloneCmd = ''
    ${pkgs.coreutils}/bin/install -d -m700 /var/lib/rclone-backup
    if [ ! -f ${rcloneLive} ]; then
      ${pkgs.coreutils}/bin/install -m600 ${rcloneSeed} ${rcloneLive}
    fi
  '';
  seedRcloneScript = pkgs.writeShellScript "seed-rclone-config" seedRcloneCmd;

  # sudo + the right repo/password env, pointed straight at restic so anything
  # after the alias is passed through (`restic_local snapshots`, etc.).
  resticWrapper = env: "sudo ${env} RESTIC_PASSWORD_FILE=${secretsFile} ${pkgs.restic}/bin/restic";

  # Weekly maintenance drives the module-generated `restic-<job>` wrapper (see
  # createWrapper), which already exports the repo/password/rclone env, so
  # nothing here restates credentials. Order: clear stale locks, apply retention
  # + prune (the repack), then verify integrity. checkArgs lets the local job do
  # cheap partial data verification (bit-rot on the USB disk) while the remote
  # stays structural-only to avoid OneDrive egress.
  resticBin = job: "/run/current-system/sw/bin/restic-${job}";
  maintenanceExec = { job, checkArgs ? "" }: [
    "${resticBin job} unlock"
    "${resticBin job} forget --prune ${lib.concatStringsSep " " retentionPolicy}"
    "${resticBin job} check ${checkArgs}"
  ];
in
{
  services.restic.backups = {
    localbackup = commonOpts // {
      paths = commonPaths ++ [ immichPath ];
      repository = localRepo;
      timerConfig.OnCalendar = "01:30";
    };

    remotebackup = commonOpts // {
      paths = commonPaths;
      repository = remoteRepo;
      rcloneConfigFile = rcloneLive;        # writable copy, NOT the read-only secret
      backupPrepareCommand = seedRcloneCmd; # seed the writable config before each run
      timerConfig.OnCalendar = "02:30";
    };
  };

  # Guard against backing up empty ZFS mountpoints: if the data pool hasn't
  # mounted (e.g. zfs-mount failed), the /data/* source dirs would exist but be
  # empty, and restic would silently snapshot nothing. RequiresMountsFor ties
  # each job to the relevant mounts. /mnt/usb-backup is also the local repo.
  systemd.services.restic-backups-localbackup.unitConfig.RequiresMountsFor = [ "/mnt/usb-backup" "/data" ];
  systemd.services.restic-backups-localbackup.serviceConfig.ExecStartPre =
      "${pkgs.util-linux}/bin/mountpoint -q /mnt/usb-backup";

  systemd.services.restic-backups-remotebackup.unitConfig.RequiresMountsFor = [ "/data" ];

  # Weekly maintenance: forget + prune (repack) + integrity check, kept off the
  # nightly timers. Scheduled after the nightly window and staggered by repo;
  # restic's own repo lock serialises any accidental overlap with a backup.
  systemd.services.restic-maintenance-localbackup = {
    after = [ "restic-backups-localbackup.service" ];
    unitConfig.RequiresMountsFor = [ "/mnt/usb-backup" ];
    serviceConfig = {
      Type = "oneshot";
      CacheDirectory = "restic-backups-localbackup";  # reuse the backup job's warm cache
      ExecStart = maintenanceExec { job = "localbackup"; checkArgs = "--read-data-subset=2%"; };
    };
  };

  systemd.services.restic-maintenance-remotebackup = {
    after = [ "restic-backups-remotebackup.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      CacheDirectory = "restic-backups-remotebackup";
      ExecStartPre = "${seedRcloneScript}";           # ensure the live rclone.conf exists
      ExecStart = maintenanceExec { job = "remotebackup"; };
    };
  };

  systemd.timers.restic-maintenance-localbackup = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "Sun 04:00"; Persistent = true; };
  };
  systemd.timers.restic-maintenance-remotebackup = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "Sun 05:00"; Persistent = true; };
  };

  # Drop-in restic wrappers: everything after the alias is passed straight to
  # restic against the right repo, e.g. `restic_local snapshots`,
  # `restic_remote check`, `restic_local restore latest --target /tmp/r`.
  # (fish shellAliases append $argv, so subcommands and flags just work.)
  programs.fish.shellAliases = {
    restic_local = resticWrapper "RESTIC_REPOSITORY=${localRepo}";
    restic_remote = resticWrapper "RCLONE_CONFIG=${rcloneLive} RESTIC_REPOSITORY=${remoteRepo}";
  };

  # restic backups run as root, so the default sops owner/mode (root:root 0400) is fine.
  sops.secrets.restic_password = { };
  sops.secrets.rclone_conf = { };
}

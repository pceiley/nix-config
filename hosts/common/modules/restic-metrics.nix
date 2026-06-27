# Emits restic backup freshness metrics to the node_exporter textfile collector.
#
# For every restic backup defined on this host, an hourly timer queries the
# latest snapshot and writes node_exporter-scraped metrics:
#   restic_backup_last_snapshot_timestamp_seconds{repo="<name>"}  (epoch)
#   restic_backup_query_success{repo="<name>"}                    (1 reachable / 0 not)
# Prometheus alerts on staleness (timer stalled, repo unreachable, token dead)
# and on the query failing - the silent-failure modes unit state alone misses.

{ config, pkgs, lib, ... }:

let
  textfileDir = "/var/lib/node_exporter/textfile";
  backups = config.services.restic.backups;

  # one metrics-collection snippet per defined backup, reusing its own repo,
  # password file, rclone config and sftp transport so remote/sftp repos work.
  perRepo = name: b: ''
    repo=${lib.escapeShellArg b.repository}
    ${lib.optionalString (b.rcloneConfigFile != null)
      "export RCLONE_CONFIG=${lib.escapeShellArg b.rcloneConfigFile}"}
    if ts=$(${pkgs.restic}/bin/restic -r "$repo" -p ${lib.escapeShellArg b.passwordFile} \
              ${lib.escapeShellArgs (lib.concatMap (o: [ "-o" o ]) b.extraOptions)} \
              snapshots --json --latest 1 2>/dev/null \
            | ${pkgs.jq}/bin/jq -r 'max_by(.time) | .time' 2>/dev/null) \
       && [ -n "$ts" ] && [ "$ts" != "null" ]; then
      epoch=$(${pkgs.coreutils}/bin/date -d "$ts" +%s)
      printf 'restic_backup_last_snapshot_timestamp_seconds{repo="%s"} %s\n' ${lib.escapeShellArg name} "$epoch" >> "$TMP"
      printf 'restic_backup_query_success{repo="%s"} 1\n' ${lib.escapeShellArg name} >> "$TMP"
    else
      printf 'restic_backup_query_success{repo="%s"} 0\n' ${lib.escapeShellArg name} >> "$TMP"
    fi
  '';

  collectScript = pkgs.writeShellScript "restic-metrics" ''
    set -uo pipefail
    ${pkgs.coreutils}/bin/install -d -m755 ${textfileDir}
    TMP=$(${pkgs.coreutils}/bin/mktemp)
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList perRepo backups)}
    ${pkgs.coreutils}/bin/install -m644 "$TMP" ${textfileDir}/restic.prom
    ${pkgs.coreutils}/bin/rm -f "$TMP"
  '';
in
lib.mkIf (backups != { }) {
  # node_exporter needs the textfile collector pointed at our dir.
  services.prometheus.exporters.node = {
    enabledCollectors = [ "textfile" ];
    extraFlags = [ "--collector.textfile.directory=${textfileDir}" ];
  };

  systemd.services.restic-metrics = {
    description = "Write restic backup freshness metrics";
    # rclone on PATH so restic can reach onedrive repos; ssh for sftp repos.
    path = [ pkgs.rclone pkgs.openssh ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = collectScript;
    };
  };

  systemd.timers.restic-metrics = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
      RandomizedDelaySec = "5m";
    };
  };
}

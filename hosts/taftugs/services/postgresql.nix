# Postgresql
#
{ pkgs, config, lib, ... }:
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
  };

  # This script is exclusively for major version upgrades
  # Cobbled together from various sources:
  #   https://nixos.org/manual/nixos/stable/#module-postgresql
  #   https://www.monotux.tech/posts/2025/11/upgrading-postgresql-version-nixos/
  #   https://kevincox.ca/2025/08/24/nixos-postgres-upgrade/
  #
  # Destructions:
  # - Become root
  # - Run upgrade-pg-cluster and ensure it's successful
  # - Change 'services.postgresql.package' to the upgraded version
  # - nixos-rebuild switch
  # - verify it's running on the new version
  # - Do the things that pg_upgrade tells you to tidy up
  #   (eg. update extensions, vacuum, delete old version)

  # environment.systemPackages = [
  #   (
  #     let
  #       # XXX specify the postgresql package you'd like to upgrade to.
  #       # Do not forget to list the extensions you need.
  #       newPostgres = pkgs.postgresql_17.withPackages (pp: [
  #         pp.pgvector
  #         pp.vectorchord
  #       ]);
  #       cfg = config.services.postgresql;
  #     in
  #     pkgs.writeScriptBin "upgrade-pg-cluster" ''
  #       set -eux
  #       # XXX it's perhaps advisable to stop all services that depend on postgresql
  #       systemctl stop postgresql

  #       export NEWDATA="/var/lib/postgresql/${newPostgres.psqlSchema}"
  #       export NEWBIN="${newPostgres}/bin"

  #       export OLDDATA="${cfg.dataDir}"
  #       export OLDBIN="${cfg.finalPackage}/bin"

  #       install -d -m 0700 -o postgres -g postgres "$NEWDATA"
  #       cd "$NEWDATA"
  #       sudo -u postgres "$NEWBIN/initdb" -D "$NEWDATA" ${lib.escapeShellArgs cfg.initdbArgs}

  #       sudo -u postgres "$NEWBIN/pg_upgrade" \
  #         --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
  #         --old-bindir "$OLDBIN" --new-bindir "$NEWBIN" \
  #         --new-options "-c shared_preload_libraries='vchord.so'" \
  #         "$@"
  #     ''
  #   )
  # ];
}

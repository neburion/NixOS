{ config, lib, pkgs, ... }:

# Fleet-wide restic backup, to two destinations.
#
# Each user declares what to back up via `backup.paths.<user> = [ ... ];`
# in their dirs.nix (or wherever fits). This module reads all declarations,
# filters to users that actually exist on this host, and generates one
# `services.restic.backups.<user>` per matching entry.
#
# A job named `root` is the exception, and means machine state rather than one
# person's files — `/var/lib` on a server, where the data belongs to service
# users with 0750 directories that no single one of them can read past. It is
# namespaced by hostname instead of by user, because otherwise two machines
# backing up /var/lib as root would share one repository called `root`.
#
# Two destinations, one declaration. Every job is generated twice: once to
# Cloudflare R2, once to the append-only REST server on personal-server (see
# services/backup/server.nix). `<user>` goes to R2 at 06:00; `<user>-mirror`
# goes to the server at 06:30.
#
# The second one is not just a spare copy. The R2 credentials on this machine
# can delete the R2 repository, so a mirror that accepted deletes from the same
# machine would share its blast radius. The mirror refuses them, which is also
# why its `pruneOpts` are empty and the server applies retention itself.
#
# personal-server does not mirror to itself; its one job goes to R2 only.
#
# Data model:
# - One R2 bucket `backup` shared across all users.
# - Restic repository per user at `s3://backup/<user>` (subpath), or per host
#   at `s3://backup/<hostname>` for a root job, so snapshots are namespaced by
#   whoever owns them while bucket administration stays simple.
# - Single restic passphrase for the whole fleet (in sops); simplifies
#   recovery because you only remember one thing.
# - Restic client-side encrypts everything with that passphrase BEFORE
#   uploading — Cloudflare only ever sees opaque ciphertext blobs.
#
# Schedule + retention:
# - 06:00 daily, Persistent = true (catch-up if system was offline).
# - Keep 7 daily + 4 weekly + 12 monthly snapshots, auto-prune older.
# - Exclusions strip common cache/junk that shouldn't consume R2 space.
#
# R2 credentials must be in secrets/common.yaml (see keys below); if not,
# activation fails with a clear "missing sops secret" error.

let
  cfAccountId = "9d41f4bba622cd7819f194785e1b9155";
  r2Endpoint  = "https://${cfAccountId}.r2.cloudflarestorage.com";
  bucket      = "backup";

  # The second destination — a restic REST server on personal-server. See
  # services/backup/server.nix for what it is and why it is append-only.
  mirrorHost = "personal-server";
  mirrorPort = 8000;
  mirrorUser = "fleet";

  # A job named `root` is the machine's state rather than one person's, so it
  # is filed under the hostname. Both destinations use the same rule, so a
  # repository means the same thing wherever you find it.
  repoName = user: if user == "root" then config.networking.hostName else user;

  # Common exclude patterns — caches, trash, build junk. Not sensitive to
  # missing paths; restic ignores excludes that don't exist.
  standardExcludes = [
    "**/.cache"
    "**/.local/share/Trash"
    "**/.mozilla/*/Cache"
    "**/.mozilla/*/OfflineCache"
    "**/.thunderbird/*/ImapMail/*/INBOX-tmp"
    "**/.thunderbird/*/global-messages-db.sqlite"
    "**/.local/share/flatpak"
    "**/node_modules"
    "**/target"          # rust build output
    "**/result"          # nix build output symlinks
    "**/.nix-profile"
  ];

  # Per-host activation = whether this module is imported. So on home-server
  # (which doesn't import this file) no backup ever runs. Deliberately don't
  # filter by config.users.users existence — that would create an infinite
  # recursion (we set extraGroups on users.users based on activePaths, but
  # activePaths depends on users.users).
  activePaths = config.backup.paths;

  # personal-server does not mirror to itself. A second copy on the same disk
  # is not a backup, and the one job it has already goes to R2.
  mirroring = config.networking.hostName != mirrorHost;
in
{
  options.backup.paths = lib.mkOption {
    type        = lib.types.attrsOf (lib.types.listOf lib.types.str);
    default     = { };
    description = ''
      Absolute paths to back up per user. Each entry becomes a nightly restic
      job scoped to that user, uploading to Cloudflare R2 at s3://backup/<user>
      — or s3://backup/<hostname> for a `root` entry, which means machine state
      rather than one person's files. Users declared but not present on this
      host are skipped.
    '';
  };

  config = lib.mkIf (activePaths != { }) {
    # `restic-backup` group — every backup user gets added, sops secrets
    # are chowned to it (mode 0440) so the restic services running as
    # different users can all read the shared passphrase + R2 creds
    # without giving them 0444 world-read.
    users.groups.restic-backup = { };
    users.users = lib.mapAttrs (user: _paths: {
      extraGroups = [ "restic-backup" ];
    }) activePaths;

    # Secrets: passphrase + R2 S3 credentials. All fleet-wide in common.yaml.
    sops.secrets = {
      restic-passphrase = {
        sopsFile = ../../../../secrets/common.yaml;
        group    = "restic-backup";
        mode     = "0440";
      };
      r2-backup-access-key-id = {
        sopsFile = ../../../../secrets/common.yaml;
        group    = "restic-backup";
        mode     = "0440";
      };
      r2-backup-secret-access-key = {
        sopsFile = ../../../../secrets/common.yaml;
        group    = "restic-backup";
        mode     = "0440";
      };
    };

    # The mirror's HTTP password. Declared even on the host that does no
    # mirroring, because it costs a file and keeps the two branches of this
    # module from disagreeing about what exists.
    sops.secrets.restic-rest-password = {
      sopsFile = ../../../../secrets/common.yaml;
      group    = "restic-backup";
      mode     = "0440";
    };

    # Both destinations' credentials, rendered by sops-nix at activation with
    # the decrypted values interpolated.
    #
    # The mirror gets one file per job rather than a `repository` string in the
    # unit, because the URL carries the password and a unit file is
    # world-readable — `systemctl cat restic-backups-neburion-mirror` would
    # otherwise print it. The restic module reads the path as
    # $RESTIC_REPOSITORY_FILE.
    sops.templates =
      {
        # Consumed by the R2 jobs via EnvironmentFile.
        "restic-r2-env" = {
          content = ''
            AWS_ACCESS_KEY_ID=${config.sops.placeholder.r2-backup-access-key-id}
            AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.r2-backup-secret-access-key}
          '';
          group = "restic-backup";
          mode  = "0440";
        };
      }
      // lib.mapAttrs' (user: _paths:
        lib.nameValuePair "restic-mirror-${user}" {
          content = "rest:http://${mirrorUser}:"
                    + config.sops.placeholder.restic-rest-password
                    + "@${mirrorHost}:${toString mirrorPort}/${repoName user}";
          group = "restic-backup";
          mode  = "0440";
        }) (lib.optionalAttrs mirroring activePaths);

    services.restic.backups = lib.mapAttrs (user: paths: {
      inherit user paths;
      # See the header: a root job is the machine's state, not a person's, so
      # it is filed under the hostname. Retention is unaffected either way —
      # `restic forget` groups by host and paths before applying --keep-*.
      repository      = "s3:${r2Endpoint}/${bucket}/${repoName user}";
      passwordFile    = config.sops.secrets.restic-passphrase.path;
      environmentFile = config.sops.templates."restic-r2-env".path;
      initialize      = true;   # `restic init` if the repo doesn't exist yet
      exclude         = standardExcludes;
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 12"
      ];
      timerConfig = {
        OnCalendar = "*-*-* 06:00:00";
        # Persistent = true → if the system was off at 06:00, run the backup
        # as soon as it boots. Handles the "laptop was closed" case cleanly.
        Persistent = true;
        # Random 15-min jitter so multiple backup jobs across hosts don't
        # all hammer R2 simultaneously.
        RandomizedDelaySec = "15min";
      };
    }) activePaths

    # The same paths again, to the append-only server on personal-server.
    // lib.mapAttrs' (user: paths:
      lib.nameValuePair "${user}-mirror" {
        inherit user paths;
        repositoryFile = config.sops.templates."restic-mirror-${user}".path;
        passwordFile   = config.sops.secrets.restic-passphrase.path;
        initialize     = true;
        exclude        = standardExcludes;

        # Empty on purpose, and the reason the server prunes itself. The
        # destination refuses deletes, so a `forget --prune` here would fail
        # every night — retention for this copy lives in
        # services/backup/server.nix.
        pruneOpts = [ ];

        # No local cache. The server's own prune removes index files behind
        # this client's back, and a cached index naming a file that is gone
        # fails the next backup with `<index/…> does not exist` — restic
        # issue #3963. The repository is a couple of hundred megabytes, so
        # re-reading the index each night costs seconds and removes the whole
        # failure class.
        extraBackupArgs = [ "--no-cache" ];

        timerConfig = {
          # Half an hour after R2, so the two never read the same files at
          # once, and a long way from the server's Sunday 04:00 prune.
          OnCalendar = "*-*-* 06:30:00";
          Persistent = true;
          RandomizedDelaySec = "15min";
        };
      }) (lib.optionalAttrs mirroring activePaths);
  };
}

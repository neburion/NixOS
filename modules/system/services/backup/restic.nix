{ config, lib, pkgs, ... }:

# Fleet-wide restic backup to Cloudflare R2.
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

    # sops-nix renders this file at activation with the decrypted secret
    # values interpolated. Consumed by restic via EnvironmentFile.
    sops.templates."restic-r2-env" = {
      content = ''
        AWS_ACCESS_KEY_ID=${config.sops.placeholder.r2-backup-access-key-id}
        AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.r2-backup-secret-access-key}
      '';
      group = "restic-backup";
      mode  = "0440";
    };

    services.restic.backups = lib.mapAttrs (user: paths: {
      inherit user paths;
      # See the header: a root job is the machine's state, not a person's, so
      # it is filed under the hostname. Retention is unaffected either way —
      # `restic forget` groups by host and paths before applying --keep-*.
      repository      = "s3:${r2Endpoint}/${bucket}/"
                        + (if user == "root" then config.networking.hostName else user);
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
    }) activePaths;
  };
}

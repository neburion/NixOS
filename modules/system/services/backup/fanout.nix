{ config, lib, pkgs, ... }:

# Fan-out — this host holds a full copy of every machine's backup, so it feeds
# every further destination itself instead of asking the laptops to upload
# again.
#
# `restic copy` moves snapshots between repositories. The mirror repositories in
# backup.server.dataDir are already complete, so a third destination is a copy
# from here rather than a third job on every host.
#
# ── Why not just add another job to the clients ──────────────────────────────
#
#   client fan-out                     fan-out from here
#   reads its disk once per target     reads once, ever
#   uploads once per target            uploads once, ever
#   a new target edits every host      a new target is one entry, one host
#   holds every target's credentials   holds none of them
#
# The last line is the one that matters. Append-only means a compromised laptop
# cannot *delete* the mirror. This means a compromised laptop cannot *reach*
# Backblaze at all, because no credential for it exists on that machine. The
# keys live here, on the box whose whole job is to be boring.
#
# pod042 keeps its direct R2 job regardless. If this host is down, snapshots
# should still be reaching a cloud somewhere without waiting for it to come
# back — belt stays on, this is braces.
#
# ── What a destination costs ─────────────────────────────────────────────────
#
# `copy` re-encrypts: the source and destination repositories have different
# master keys even when the passphrase is the same, so every snapshot is read,
# decrypted, re-encrypted and written. At a couple of hundred megabytes that is
# seconds. It would not be, at a terabyte.
#
# Destinations are initialised with `--copy-chunker-params` from the source. Get
# that wrong and restic re-chunks everything, deduplication quietly stops
# matching, and the destination stores several times what it should while
# looking entirely healthy.
#
# Unlike the mirror, these destinations are *not* append-only: this host holds
# their keys, so it prunes them here, where the keys are.

let
  inherit (lib) mkOption types mapAttrs' nameValuePair mapAttrsToList
                concatStringsSep;

  cfg = config.backup.fanout;
  srcDir = config.backup.server.dataDir;

  # `<app>-<key>` is the app platform's naming; this is the same idea for a
  # destination — a credential is named for the destination that uses it, so
  # one cannot quietly read another's.
  secretName = dest: var: "backup-${dest}-${lib.toLower (builtins.replaceStrings [ "_" ] [ "-" ] var)}";

  copyTo = name: dest: pkgs.writeShellApplication {
    name = "restic-fanout-${name}";
    runtimeInputs = [ pkgs.restic ];
    text = ''
      # Both halves of a copy need a passphrase, and the fleet has one.
      export RESTIC_PASSWORD_FILE="$CREDENTIALS_DIRECTORY/passphrase"
      export RESTIC_FROM_PASSWORD_FILE="$CREDENTIALS_DIRECTORY/passphrase"
      shopt -s nullglob

      failed=0
      for src in ${srcDir}/*/; do
        # A directory a client started but never finished initialising has no
        # config file, and copying from it would fail in a less obvious way.
        [ -f "$src/config" ] || continue
        repo="$(basename "$src")"
        target="${dest.repository}/$repo"
        echo "── $repo → ${name}"

        # `cat config` is the cheap existence test; `snapshots` would need the
        # index and a lock for a question that is only about one small object.
        if ! restic -r "$target" cat config >/dev/null 2>&1; then
          echo "   initialising"
          # --copy-chunker-params is not optional. Without it the destination
          # picks its own chunker seed, identical files chunk differently, and
          # nothing ever deduplicates against what is already there.
          if ! restic -r "$target" init --from-repo "$src" --copy-chunker-params; then
            echo "!! could not initialise $target"
            failed=1
            continue
          fi
        fi

        # A copy leaves its lock behind if it is killed, and the next run then
        # refuses rather than retrying — observed on the very first test of
        # this, where the prune immediately after a copy hit a three-second-old
        # lock. Both ends get cleared: copy locks the source too, so a mirror
        # backup killed mid-run would otherwise block every fan-out after it.
        # Only ever removes locks whose owning process is gone, so this cannot
        # interrupt a backup that is genuinely still writing.
        restic -r "$src" unlock || true
        restic -r "$target" unlock || true

        if ! restic -r "$target" copy --from-repo "$src"; then
          echo "!! copy failed for $repo"
          failed=1
          continue
        fi

        # Pruned here because the keys are here. The mirror cannot do this to
        # itself — it refuses deletes on purpose — but a destination this host
        # owns outright has no reason to grow forever.
        if ! restic -r "$target" forget --prune ${toString config.backup.keep}; then
          echo "!! prune failed for $repo at ${name}"
          failed=1
        fi
      done
      exit "$failed"
    '';
  };
in
{
  options.backup.fanout = mkOption {
    default = { };
    description = ''
      Further destinations, fed by copying from the mirrored repositories this
      host already holds rather than by another job on every client.

      Each entry becomes its own unit and timer, so one provider having a bad
      night is visible as itself on the dashboard instead of taking the others
      down with it.
    '';
    type = types.attrsOf (types.submodule {
      options = {
        repository = mkOption {
          type = types.str;
          example = "s3:s3.us-west-004.backblazeb2.com/fleet-backup";
          description = ''
            Base repository. The mirrored repository's own name is appended, so
            a destination holds `<base>/neburion` and `<base>/pod042` the same
            way R2 and the mirror do — a repository means the same thing
            wherever you find it.
          '';
        };
        credentials = mkOption {
          type = types.attrsOf types.str;
          default = { };
          example = { AWS_ACCESS_KEY_ID = "b2-key-id"; };
          description = ''
            Environment variable → the sops key in this host's secrets file
            holding its value. Rendered into an EnvironmentFile, so the values
            never appear in a unit or on a command line.
          '';
        };
        onCalendar = mkOption {
          type = types.str;
          default = "*-*-* 07:00:00";
          description = ''
            Default is half an hour after the mirror jobs land, so a fan-out
            carries the night's snapshots rather than yesterday's.
          '';
        };
      };
    });
  };

  config = lib.mkIf (cfg != { }) {
    # One secret per declared credential, named for its destination.
    sops.secrets = builtins.listToAttrs (lib.concatLists (mapAttrsToList
      (name: dest: mapAttrsToList
        (var: key: nameValuePair (secretName name var) {
          sopsFile = ../../../../secrets/${config.networking.hostName}.yaml;
          key = key;
          mode = "0400";
        })
        dest.credentials)
      cfg));

    # One environment file per destination, holding only that destination's
    # credentials — so a unit cannot be handed a key it has no business with.
    sops.templates = mapAttrs' (name: dest:
      nameValuePair "backup-fanout-${name}-env" {
        content = concatStringsSep "\n" (mapAttrsToList
          (var: _key: "${var}=${config.sops.placeholder.${secretName name var}}")
          dest.credentials);
        mode = "0400";
      }) cfg;

    systemd.services = mapAttrs' (name: dest:
      nameValuePair "restic-fanout-${name}" {
        description = "Copy the mirrored backups out to ${name}";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${copyTo name dest}/bin/restic-fanout-${name}";
          EnvironmentFile = config.sops.templates."backup-fanout-${name}-env".path;
          # The same user that owns the repositories, so reading them needs no
          # extra grant and nothing it writes changes their ownership.
          User = "restic";
          Group = "restic";
          LoadCredential = "passphrase:${config.sops.secrets.restic-passphrase.path}";
          ReadWritePaths = [ srcDir ];
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          NoNewPrivileges = true;
          RestrictNamespaces = true;
          LockPersonality = true;
          SystemCallArchitectures = "native";
        };
      }) cfg;

    systemd.timers = mapAttrs' (name: dest:
      nameValuePair "restic-fanout-${name}" {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = dest.onCalendar;
          Persistent = true;
          RandomizedDelaySec = "20min";
        };
      }) cfg;
  };
}

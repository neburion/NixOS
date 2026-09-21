{ config, pkgs, ... }:

# The fleet's second backup destination — a restic REST server, so the nightly
# jobs have somewhere to go that is not Cloudflare.
#
# ── Why a second destination at all ──────────────────────────────────────────
#
# The R2 credentials sitting on pod042 can delete the R2 repository. A second
# copy that accepts deletes from the same machine is therefore not a second
# destination; it is two copies of one trust boundary, and one bad `restic
# forget` or one bad afternoon takes both. So this server runs **append-only**:
# a client may create a snapshot and may never remove one.
#
# That is the whole point, and it has a price. Append-only refuses `forget
# --prune`, so the client jobs run with pruning switched off and this host
# prunes its own repositories on a timer, locally, where the HTTP layer that
# forbids deletion is not in the way. See `restic-mirror-prune` below.
#
# ── /var/backup, not /var/lib ────────────────────────────────────────────────
#
# The module's default dataDir is /var/lib/restic, and this host's own backup
# policy is `/var/lib` entire. Left alone, the nightly R2 job would upload
# every other machine's backup history, growing without bound, forever. Putting
# the repositories outside /var/lib keeps `policy/backup.nix` honest — that
# file's virtue is that a new app is backed up the day it is deployed without
# anyone remembering to list it, and an exclusion list is exactly the
# remembering it exists to avoid.
#
# Reachable on the tailnet only. Everything stored here is ciphertext restic
# encrypted before it left the client, so the password on the door is about who
# may fill the disk, not about who may read the backups.

let
  dataDir = "/var/backup/restic";
  port = 8000;

  # Retention, and the one place it is written down for this destination. The
  # same numbers the R2 jobs use, applied here instead of on the client because
  # a client is not allowed to delete anything.
  keep = [ "--keep-daily 7" "--keep-weekly 4" "--keep-monthly 12" ];

  prune = pkgs.writeShellApplication {
    name = "restic-mirror-prune";
    runtimeInputs = [ pkgs.restic ];
    text = ''
      export RESTIC_PASSWORD_FILE="$CREDENTIALS_DIRECTORY/passphrase"
      shopt -s nullglob

      failed=0
      for repo in ${dataDir}/*/; do
        # A directory a client has started but not finished initialising has
        # no config file, and restic would rather be told than guess.
        [ -f "$repo/config" ] || continue
        echo "── $repo"

        # Only ever removes locks whose owning process is gone. A backup that
        # is genuinely running keeps its lock, forget then refuses, and this
        # unit fails — which is the correct outcome and shows up on the
        # dashboard rather than racing a live write.
        restic -r "$repo" unlock || true

        if ! restic -r "$repo" forget --prune ${toString keep}; then
          echo "!! prune failed for $repo"
          failed=1
        fi
      done
      exit "$failed"
    '';
  };
in
{
  services.restic.server = {
    enable = true;
    listenAddress = toString port;   # port only; the module is socket-activated
    inherit dataDir;
    appendOnly = true;
    htpasswd-file = config.sops.secrets.restic-rest-htpasswd.path;
  };

  # rest-server refuses to start rather than serve without authentication, so
  # this file is load-bearing, not decoration. It holds a bcrypt line made with
  # `htpasswd -nbB`; the matching plaintext is `restic-rest-password`, which is
  # what the clients put in their repository URL.
  sops.secrets.restic-rest-htpasswd = {
    sopsFile = ../../../../secrets/common.yaml;
    owner = "restic";
    mode = "0400";
    # The server reads this once at start, so rotating the pair without a
    # restart leaves the retired password working while the deploy says
    # nothing at all.
    restartUnits = [ "restic-rest-server.service" ];
  };

  systemd.services.restic-mirror-prune = {
    description = "Apply retention to the mirrored restic repositories";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${prune}/bin/restic-mirror-prune";
      # Runs as the server's own user so every file in the repository keeps one
      # owner. A prune running as root would leave root-owned index files in a
      # tree the server has to keep writing to.
      User = "restic";
      Group = "restic";
      # Read as root at unit start and handed over after the User= drop, which
      # keeps the passphrase out of the process environment table.
      LoadCredential = "passphrase:${config.sops.secrets.restic-passphrase.path}";
      ReadWritePaths = [ dataDir ];
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      RestrictNamespaces = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
    };
  };

  systemd.timers.restic-mirror-prune = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Sunday 04:00 — deliberately nowhere near 06:00 (R2) or 06:30 (the
      # mirror jobs). Pruning underneath a running backup is the one way this
      # arrangement breaks, and weekly at four in the morning is the cheapest
      # way to never be near it.
      OnCalendar = "Sun *-*-* 04:00:00";
      Persistent = true;
      RandomizedDelaySec = "20min";
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
}

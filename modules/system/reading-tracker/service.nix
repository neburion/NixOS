{ config, pkgs, ... }:

# Reading tracker — SQLite + a small web UI on :8778, tailnet only.
#
# Stdlib Python only: no Flask, no pip. `sqlite3` ships with pkgs.python3 and
# nixpkgs builds it with FTS5, which the search endpoint needs. Same shape as
# elden-ring-tracker, deliberately: schema.sql + seed.json + seed.py as an
# ExecStartPre, app.py serving the API, ui.html as the UI.
#
# One important difference from that module. There, seed.json is the game's
# reference checklist, so the seeder drops and rebuilds the reference tables on
# every start and only your ticks are preserved. Here seed.json is a snapshot of
# an Obsidian vault, and *everything* in it — chapter, rating, status — is the
# mutable state the app exists to edit. So seeding is additive and keyed on
# title: new titles are inserted, existing rows are never touched. The first
# start imported 300 series from the vault; a later one added 617 more from an
# Anime-Planet export, and every start in between and since is a no-op.
#
# tags.json is the other half and works differently: it is a classification of
# every title on all three tag axes, applied *once*, as a recorded migration,
# precisely because re-applying it would overwrite tags edited by hand. See
# apply_tags() in seed.py.
#
# Store vs. state. app.py/seed.py/seed.json live in the read-only store; the
# database and the cover cache do not. Both read RT_* from the environment and
# fall back to paths next to the script, so the same files run straight out of a
# git checkout with no arguments.

let
  port = 8778;

  stateDir = "/var/lib/reading-tracker";

  src = ./.;

  # Self-hosted webfonts, converted once at build time. Literata is Google's
  # e-reader typeface and the right serif for a shelf of books; Public Sans
  # carries the interface and Plex Mono the figures, so chapter counts and
  # ratings line up in a column. No CDN is reachable from a tunnel-only host
  # anyway, and a default system-sans stack is the loudest "generated page" tell.
  fonts = pkgs.runCommand "reading-tracker-fonts" { } ''
    mkdir -p $out
    lit=${pkgs.literata}/share/fonts/truetype
    pub=${pkgs.public-sans}/share/fonts/truetype
    plex=${pkgs.ibm-plex}/share/fonts/truetype
    for f in \
      "$lit/Literata-Regular.ttf:literata" \
      "$lit/Literata-SemiBold.ttf:literata-semibold" \
      "$lit/Literata-Italic.ttf:literata-italic" \
      "$pub/PublicSans-Regular.ttf:publicsans" \
      "$pub/PublicSans-Medium.ttf:publicsans-medium" \
      "$pub/PublicSans-SemiBold.ttf:publicsans-semibold" \
      "$plex/IBMPlexMono-Regular.ttf:mono" \
    ; do
      srcfile="''${f%%:*}"; name="''${f##*:}"
      cp "$srcfile" "$out/$name.ttf"
      ${pkgs.woff2}/bin/woff2_compress "$out/$name.ttf"
      rm "$out/$name.ttf"
    done
  '';

  env = {
    RT_DB = "${stateDir}/reading.db";
    RT_SEED = "${src}/seed.json";
    RT_TAGS = "${src}/tags.json";
    RT_SCHEMA = "${src}/schema.sql";
    RT_UI = "${src}/ui.html";
    RT_FONTS = "${fonts}";
    RT_CACHE = stateDir;
    RT_HOST = "0.0.0.0";
    RT_PORT = toString port;
    # The half of the login that is not secret. Its password is the sops secret
    # below; keeping both halves in one file beats splitting them across two.
    RT_USERNAME = "tracker";
  };

  python = pkgs.python3;

  # `${src}/…`, not `${./app.py}`: app.py imports seed.py from beside itself, so
  # the whole directory has to land in the store rather than one file.
  seedDb = pkgs.writeShellApplication {
    name = "reading-tracker-seed";
    runtimeInputs = [ python ];
    text = ''exec python3 ${src}/seed.py "$@"'';
  };

  tracker = pkgs.writeShellApplication {
    name = "reading-tracker";
    runtimeInputs = [ python ];
    text = ''exec python3 ${src}/app.py "$@"'';
  };
in
{
  users.users.reading = {
    isSystemUser = true;
    group = "reading";
  };
  users.groups.reading = { };

  # HTTP Basic Auth password for the UI. Rotate with:
  #   sops secrets/personal-server.yaml   (edit reading-tracker-password)
  #   git commit && git push && rebuild personal-server
  #
  # `restartUnits` is load-bearing, not tidiness. LoadCredential snapshots the
  # password into the service's credential directory at unit start, and app.py
  # reads it once at import. Rotating the secret rewrites /run/secrets and
  # changes nothing else, so without this the unit is not restarted, the running
  # process keeps the old password in memory, and the deploy prints
  # "modifying secret: …" and a cheerful "Done." while the credential you just
  # retired still works. Found exactly that way.
  sops.secrets.reading-tracker-password = {
    sopsFile = ../../../secrets/personal-server.yaml;
    mode = "0400";
    restartUnits = [ "reading-tracker.service" ];
  };

  systemd.services.reading-tracker = {
    description = "Reading tracker";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment = env;

    serviceConfig = {
      ExecStartPre = "${seedDb}/bin/reading-tracker-seed";
      ExecStart = "${tracker}/bin/reading-tracker";

      # Read as root at unit start, handed to the service at
      # $CREDENTIALS_DIRECTORY/password after the User= drop. Same approach as
      # the Elden Ring tracker and the print server: avoids EnvironmentFile's
      # ordering problem and keeps the password out of the process environment.
      LoadCredential = "password:${config.sops.secrets.reading-tracker-password.path}";

      Restart = "on-failure";
      RestartSec = "5s";
      User = "reading";
      Group = "reading";

      # Creates and chowns /var/lib/reading-tracker and keeps it across deploys
      # and reboots. The database is the only thing here worth backing up; the
      # covers beside it are a cache and cost one re-download each.
      StateDirectory = "reading-tracker";
      StateDirectoryMode = "0750";

      # Nothing here touches hardware or other users' files. It does reach the
      # network, but only outbound, to fetch cover images.
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      # AF_UNIX is needed for name resolution, which the cover fetcher uses.
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      RestrictNamespaces = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
    };
  };

  # Covers are fetched lazily on first view and cached forever after, which
  # makes exactly one page load slow — the first. This warms the cache instead,
  # shortly after boot and weekly thereafter to pick up newly added series. It
  # is a convenience, not a dependency: the tracker works with it switched off
  # or with every image host gone, drawing a tinted plate with the title on it.
  systemd.services.reading-tracker-covers = {
    description = "Warm the reading tracker's cover cache";
    after = [ "network-online.target" "reading-tracker.service" ];
    wants = [ "network-online.target" ];
    environment = env;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${tracker}/bin/reading-tracker --warm-covers";
      User = "reading";
      Group = "reading";
      StateDirectory = "reading-tracker";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
    };
  };

  systemd.timers.reading-tracker-covers = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3min";
      OnUnitActiveSec = "1w";
      Persistent = true;
    };
  };

  # `reading-tracker --stats` prints the shelf from a terminal on the host.
  environment.systemPackages = [ tracker ];

  # The listener binds 0.0.0.0, but the only interface the port is opened on is
  # tailscale0 — nothing on the LAN can reach it. If this ever gets a public
  # hostname the way eldenring.azuresalt.app did, cloudflared reaches it over
  # loopback from inside the host and needs no firewall rule at all; the Basic
  # Auth gate above is what would stand behind a missing Access policy.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
}

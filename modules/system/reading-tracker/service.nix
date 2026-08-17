{ config, pkgs, ... }:

# Reading tracker — a web UI over the Reading-Ob Obsidian vault, on :8778,
# reachable over the tailnet.
#
# Stdlib Python only: no Flask, no pip, and no database. The vault's markdown
# notes *are* the database — vault.py reads and writes their frontmatter in
# place. That is the whole design decision here and it drives everything else:
#
#   * It runs on pod042 rather than a server, because pod042 is where the vault
#     is and where Obsidian edits it. A copy on personal-server would be a
#     second source of truth, and two sources of truth for a reading list means
#     one of them is wrong.
#   * It runs as `neburion`, not a system user, because the notes are that
#     user's files. ProtectHome is therefore off and the vault is the only
#     writable path granted.
#   * Writes are surgical and merge-on-write, so having the app and Obsidian
#     open at once is fine.
#
# The only state it owns is the cover-image cache, which is derived data and
# safe to lose.

let
  port = 8778;

  # The vault. A host fact rather than a behaviour knob — this module exists to
  # serve this directory, and a second vault would be a second import.
  vault = "/home/neburion/Media/Books/Reading-Ob";

  user = "neburion";

  stateDir = "/var/lib/reading-tracker";

  src = ./.;

  # Self-hosted webfonts, converted once at build time. Literata is Google's
  # e-reader typeface and the right serif for a shelf of books; Public Sans
  # carries the interface and Plex Mono the figures, so chapter counts line up
  # in a column. nixpkgs ships all three as TTF/OTF only, so compress here and
  # hand the results out under /fonts/.
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
    RT_VAULT = vault;
    RT_UI = "${src}/ui.html";
    RT_FONTS = "${fonts}";
    RT_CACHE = stateDir;
    RT_HOST = "0.0.0.0";
    RT_PORT = toString port;
    # The half of the login that is not secret. Its password is the sops
    # secret below; keeping both halves in one file beats splitting them.
    RT_USERNAME = "reader";
  };

  # `${src}/app.py`, not `${./app.py}`: app.py imports vault.py from beside
  # itself, so the whole directory has to land in the store, not one file.
  tracker = pkgs.writeShellApplication {
    name = "reading-tracker";
    runtimeInputs = [ pkgs.python3 ];
    text = ''exec python3 ${src}/app.py "$@"'';
  };
in
{
  # HTTP Basic Auth password for the UI. Rotate with:
  #   sops secrets/pod042.yaml   (edit reading-tracker-password)
  #   git commit && git push && rebuild pod042
  sops.secrets.reading-tracker-password = {
    sopsFile = ../../../secrets/pod042.yaml;
    mode = "0400";
  };

  systemd.services.reading-tracker = {
    description = "Reading tracker over the Reading-Ob vault";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment = env;

    serviceConfig = {
      ExecStart = "${tracker}/bin/reading-tracker";

      # Read as root at unit start and handed to the service at
      # $CREDENTIALS_DIRECTORY/password after the User= drop — same approach as
      # the Elden Ring tracker and the print server. Keeps the password out of
      # the process environment table and sidesteps EnvironmentFile ordering.
      LoadCredential = "password:${config.sops.secrets.reading-tracker-password.path}";

      Restart = "on-failure";
      RestartSec = "5s";
      User = user;
      Group = "users";

      # Cover cache only. Losing it costs one re-download per image.
      StateDirectory = "reading-tracker";
      StateDirectoryMode = "0700";

      # ProtectHome would hide the very directory this service exists to serve,
      # so it is off and ProtectSystem=strict does the work instead: the whole
      # filesystem is read-only except the state directory and the vault. The
      # blast radius of a bug in app.py is therefore exactly the vault it is
      # already allowed to edit.
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadWritePaths = [ vault ];

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

  # Covers are fetched lazily on first view and then cached forever, which
  # makes exactly one page load slow — the first. This warms the cache instead,
  # shortly after boot and weekly thereafter to pick up newly added series.
  # It is a convenience, not a dependency: the service works with it disabled,
  # switched off, or the image hosts gone.
  systemd.services.reading-tracker-covers = {
    description = "Warm the reading tracker's cover cache";
    after = [ "network-online.target" "reading-tracker.service" ];
    wants = [ "network-online.target" ];
    environment = env;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${tracker}/bin/reading-tracker --warm-covers";
      User = user;
      Group = "users";
      StateDirectory = "reading-tracker";
      ProtectSystem = "strict";
      ProtectHome = false;
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

  # `reading-tracker --stats` prints the shelf from a terminal.
  environment.systemPackages = [ tracker ];

  # The listener binds 0.0.0.0 but the port is only opened on tailscale0, so
  # nothing on the local network can reach it — which matters more here than on
  # a server, because a laptop joins whatever café wifi it is pointed at. The
  # Basic Auth gate in app.py is the second layer, and app.py refuses to bind a
  # non-loopback address without a password, so a credential failure produces a
  # restart loop rather than an unauthenticated service on a public network.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
}

{ config, pkgs, ... }:

# Elden Ring 100% completion tracker — SQLite + a small web UI on :8777,
# reachable over the tailnet and publicly at https://eldenring.azuresalt.app
# through the Cloudflare tunnel declared in the host's cloudflare-layout.nix.
#
# Stdlib Python only: no Flask, no pip. `sqlite3` ships with pkgs.python3 and
# nixpkgs builds it with FTS5, which the search endpoint needs.
#
# Store vs. state. app.py/seed.py live in the read-only store; the database
# does not. Both read ER_DB / ER_SEED / ER_SCHEMA / ER_UI from the environment
# and fall back to paths next to the script, so the same files also run
# straight out of a git checkout with no arguments.
#
# Seeding is an ExecStartPre on every start, not a one-shot on first boot.
# seed.py rebuilds the reference tables from seed.json and re-attaches progress
# by natural key (section + group + item + position), so editing seed.json and
# redeploying migrates the live database without touching anyone's ticks. It
# prints a warning if a progress row loses its item.

let
  port = 8777;

  stateDir = "/var/lib/elden-ring-tracker";

  src = ./.;

  env = {
    ER_DB = "${stateDir}/eldenring.db";
    ER_SEED = "${src}/seed.json";
    ER_SCHEMA = "${src}/schema.sql";
    ER_UI = "${src}/ui.html";
    ER_HOST = "0.0.0.0";
    ER_PORT = toString port;
    # Login half that isn't secret. The password is the sops secret below.
    ER_USERNAME = "tracker";
  };

  python = pkgs.python3;

  seedDb = pkgs.writeShellApplication {
    name = "elden-ring-tracker-seed";
    runtimeInputs = [ python ];
    text = "exec python3 ${./seed.py}";
  };

  tracker = pkgs.writeShellApplication {
    name = "elden-ring-tracker";
    runtimeInputs = [ python ];
    text = "exec python3 ${./app.py}";
  };
in
{
  users.users.elden-ring = {
    isSystemUser = true;
    group = "elden-ring";
  };
  users.groups.elden-ring = { };

  # HTTP Basic Auth password for the UI. Rotate with:
  #   sops secrets/personal-server.yaml   (edit elden-ring-password)
  #   git commit && git push && rebuild personal-server
  sops.secrets.elden-ring-password = {
    sopsFile = ../../../secrets/personal-server.yaml;
    mode = "0400";
  };

  systemd.services.elden-ring-tracker = {
    description = "Elden Ring completion tracker";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment = env;

    serviceConfig = {
      ExecStartPre = "${seedDb}/bin/elden-ring-tracker-seed";
      ExecStart = "${tracker}/bin/elden-ring-tracker";

      # Read as root at unit start, handed to the service at
      # $CREDENTIALS_DIRECTORY/password after the User= drop. Same approach as
      # the print server: avoids EnvironmentFile's ordering problem and keeps
      # the password out of the process environment table.
      LoadCredential = "password:${config.sops.secrets.elden-ring-password.path}";

      Restart = "on-failure";
      RestartSec = "5s";
      User = "elden-ring";
      Group = "elden-ring";

      # Creates and chowns /var/lib/elden-ring-tracker, and keeps it across
      # deploys and reboots. The database is the only thing worth backing up.
      StateDirectory = "elden-ring-tracker";
      StateDirectoryMode = "0750";

      # Nothing here touches hardware, other users' files, or the network
      # beyond its own listener.
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
      RestrictNamespaces = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
    };
  };

  # The listener binds 0.0.0.0, but the only interface the port is opened on is
  # tailscale0 — nothing on the LAN can reach it. Public access comes from
  # cloudflared instead, which connects to 127.0.0.1:8777 from inside the host
  # and so needs no firewall rule at all.
  #
  # Three independent layers gate the public hostname, because two of them are
  # configured by hand and can silently go missing:
  #   1. Cloudflare Access policy — dashboard only, NOT managed by cf-reconcile.
  #   2. HTTP Basic Auth in app.py, from the sops secret above.
  #   3. app.py refuses to bind a non-loopback address with no password, so a
  #      credential failure produces a restart loop and a 502 rather than an
  #      unauthenticated service on the open internet.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
}

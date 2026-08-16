{ pkgs, ... }:

# Elden Ring 100% completion tracker — SQLite + a small web UI on :8777,
# reachable over the tailnet only.
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

  systemd.services.elden-ring-tracker = {
    description = "Elden Ring completion tracker";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment = env;

    serviceConfig = {
      ExecStartPre = "${seedDb}/bin/elden-ring-tracker-seed";
      ExecStart = "${tracker}/bin/elden-ring-tracker";
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

  # Tailnet-only. The listener binds 0.0.0.0 so it answers on the tailscale0
  # address, but the port is opened on that interface alone — nothing on the
  # LAN or the internet can reach it. There is no auth in the app, so this
  # firewall rule IS the access control. Do not point a Cloudflare tunnel at
  # this port without putting an Access policy in front of it first (see the
  # warning in hosts/personal-server/hardware-layout/cloudflare-layout.nix).
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
}

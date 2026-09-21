{ config, lib, pkgs, ... }:

# fleet-status — what this machine would say about itself, as JSON, to anyone
# on the tailnet who asks. Every host runs it; the dashboard on
# personal-server polls all of them and draws the page.
#
# Pull, not push. A host that has stopped answering *is* the down signal, which
# means there is no heartbeat to miss, no last-seen table to keep, and no
# writable endpoint anywhere in the fleet. The dashboard learns a box is gone
# by asking it.
#
# ── Two units, and why it is not one ─────────────────────────────────────────
#
#   fleet-status-collect.timer   root, every 30s, writes status.json
#   fleet-status.service         dynamic user, serves that one file on :8081
#
# The numbers worth having need privilege: another user's systemd units,
# syncthing's API key, every filesystem. The single-process version of this is
# therefore a root daemon parsing HTTP off the network, on all three hosts, for
# a dashboard. Splitting it means root writes a file and never reads a request,
# and the thing behind the socket holds nothing worth taking.
#
# The 30s cadence is the staleness floor, not a polling rate — the page shows
# `collected` and ages it, so a stuck collector reads as stale rather than as
# fine.
#
# Imported from presets/base.nix, the same as sshd: every host, tailnet only.

let
  inherit (lib) mkOption types;

  cfg = config.fleetStatus;

  port = 8081;
  stateDir = "/var/lib/fleet-status";
  statusFile = "${stateDir}/status.json";

  collect = pkgs.writeShellApplication {
    name = "fleet-status-collect";
    runtimeInputs = [
      pkgs.python3
      pkgs.systemd                       # systemctl: units, timers, health
      config.services.tailscale.package  # peer list
    ];
    text = "exec python3 ${./collect.py}";
  };

  serve = pkgs.writeShellApplication {
    name = "fleet-status-serve";
    runtimeInputs = [ pkgs.python3 ];
    text = "exec python3 ${./serve.py}";
  };

  # Shared by both units so the two halves cannot disagree about which file
  # they mean — the failure mode there is a server that serves nothing while
  # the collector cheerfully writes somewhere else.
  environment = {
    FS_OUT = statusFile;
    FS_PORT = toString port;
  };
in
{
  options.fleetStatus = {
    apps = mkOption {
      type = types.attrsOf types.port;
      default = { };
      description = ''
        Local HTTP services to knock on, as name → port. The app platform fills
        this in from its manifests; a host running no apps reports none.

        The probe exists because a unit can be `active` and still not be
        answering, which is the one failure the unit state cannot show.
      '';
    };

    syncUser = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        The user whose syncthing to report on, or null on a host that runs
        none. Named rather than discovered because the API key lives in that
        user's config.xml and nowhere else.
      '';
    };
  };

  config = {
    # Root, on a timer, writing a file. The privileged half.
    systemd.services.fleet-status-collect = {
      description = "Collect this host's state for the fleet dashboard";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${collect}/bin/fleet-status-collect";
        StateDirectory = "fleet-status";
        # 0755, not the default 0700: the serving half is a different user and
        # has to be able to walk in and read the file.
        StateDirectoryMode = "0755";
      };
      environment = environment // {
        FS_PROBES = builtins.toJSON cfg.apps;
        FS_SYNC_USER = if cfg.syncUser == null then "" else cfg.syncUser;
      };
    };

    systemd.timers.fleet-status-collect = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "30s";
        # Deliberately not Persistent: a reading taken whenever the box last
        # happened to be awake is worse than no reading, because the page would
        # draw it as current.
        Persistent = false;
      };
    };

    # The socket. Holds nothing, can reach nothing, serves one file.
    systemd.services.fleet-status = {
      description = "Serve this host's state to the fleet dashboard";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      inherit environment;
      serviceConfig = {
        ExecStart = "${serve}/bin/fleet-status-serve";
        Restart = "on-failure";
        RestartSec = "5s";
        DynamicUser = true;
        ReadOnlyPaths = [ stateDir ];
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

    # Tailnet only. There is no tunnel and no public hostname for this: the
    # dashboard is the thing with a URL, and it reaches the agents from inside
    # the mesh. Nothing here is secret, but nothing here is anyone else's
    # either.
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
  };
}

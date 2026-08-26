{ config, lib, pkgs, ... }:

# The app platform — run a project that lives in its own repo, on this host,
# behind a URL, without that project containing a line of Nix.
#
# A host declares which repos it runs (see hosts/*/hardware-layout/apps-layout.nix):
#
#     apps.instances.media-tracker = inputs.media-tracker;
#
# and everything else is read out of an `app.json` sitting at the root of that
# repo. From those few fields this module generates the systemd unit, the
# system user, the state directory, the credential wiring, the tailnet firewall
# rule and the Cloudflare tunnel — the ~190 lines of boilerplate that used to be
# copy-pasted into a service.nix per project.
#
#     {
#       "name": "media-tracker",
#       "runtime": "python3",
#       "preStart": "seed.py",
#       "run": "app.py",
#       "port": 8778,
#       "urls": ["media.azuresalt.app"],
#       "state": true,
#       "secrets": ["password"],
#       "env": { "MT_DB": "$STATE_DIR/media.db" }
#     }
#
# The contract an app has to honour, and nothing beyond it:
#
#   - listen on $PORT (bind 0.0.0.0; only the tailnet interface is opened)
#   - keep everything durable under $STATE_DIR
#   - read secrets from $CREDENTIALS_DIRECTORY/<name>
#   - exit non-zero if it cannot start
#
# JSON rather than a flake output on purpose. A flake output could compute
# things, which would mean the project repo contains Nix, which is the one
# thing this exists to avoid. An app.json is inert data any language can write
# and `builtins.fromJSON` can read.
#
# ── Why the manifest cannot simply be trusted ────────────────────────────────
#
# It is fetched from a repo, and repos get edited — by whoever can push to
# them. So every field is bounded here rather than obeyed:
#
#   port     must fall inside portRange, so a manifest cannot claim :22
#   urls     must sit under `zone`, so it cannot mint a hostname elsewhere
#   secrets  resolve to sops keys prefixed `<app name>-`, so a repo can only
#            ever reach its own password and never cloudflare-api-key
#   runtime  must name one of `runtimes`, so it cannot run an arbitrary binary
#
# Those four rules are what separate a platform from a hole. An out-of-bounds
# manifest fails evaluation with a readable message and never reaches a host.
#
# ── What this deliberately does not do ───────────────────────────────────────
#
# There is no runtime provisioning: an app appears when a rebuild says so, not
# when a repo asks. That would be a control plane, and for one server it would
# be more machinery than the thing it deploys. The pin in flake.lock is the
# feature — the app version belongs to the system generation, so a rollback
# takes the app back with it.

let
  inherit (lib) mkOption types mapAttrs nameValuePair concatMap attrValues
                optionalAttrs;

  cfg = config.apps;

  # Bounds. Everything a manifest may ask for is checked against these.
  zone = "azuresalt.app";
  portRange = { from = 8700; to = 8799; };

  # Interpreters an app may name, and the binary that runs its entry point.
  # Adding a language here is deliberate: it is the one place a manifest can
  # cause something new to execute.
  runtimes = {
    python3 = { pkg = pkgs.python3; bin = "python3"; };
    nodejs = { pkg = pkgs.nodejs; bin = "node"; };
    bash = { pkg = pkgs.bashInteractive; bin = "bash"; };
  };

  # ── reading and checking one manifest ──────────────────────────────────────

  # `run` lands inside a shell script, so it is held to a file name plus plain
  # arguments. Without this a manifest could smuggle `; curl … | sh` into a
  # unit that systemd starts as its own user on every boot — which would make
  # push access to a repo equivalent to code execution on the host.
  safeCommand = c: builtins.match "[A-Za-z0-9._/= -]*" c != null;

  readManifest = name: src:
    let
      file = "${src}/app.json";
      m = builtins.fromJSON (builtins.readFile file);

      bad = msg: throw "apps.instances.${name}: ${msg} (in ${file})";

      has = f: m ? ${f};
      req = f: if has f then m.${f} else bad "missing required field `${f}`";

      port = req "port";
      urls = m.urls or [ ];
      runtime = m.runtime or "python3";
      secrets = m.secrets or [ ];

      checked =
        if (m.name or name) != name then
          bad "declares name `${m.name}`, but the host calls it `${name}`"
        else if !(builtins.isInt port) || port < portRange.from || port > portRange.to then
          bad "port ${toString port} is outside ${toString portRange.from}-${toString portRange.to}"
        else if !(runtimes ? ${runtime}) then
          bad "unknown runtime `${runtime}`; known: ${toString (builtins.attrNames runtimes)}"
        else if !(builtins.all (u: lib.hasSuffix ".${zone}" u) urls) then
          bad "every url must sit under ${zone}"
        else if !(builtins.all (s: builtins.match "[a-z0-9-]+" s != null) secrets) then
          bad "secret names must be lowercase and dash-separated"
        else if !(builtins.all safeCommand ([ (m.run or "") ] ++ [ (m.preStart or "") ]
                                            ++ map (t: t.run or "") (m.timers or [ ]))) then
          bad "run/preStart may only name a file in the repo plus plain arguments"
        else m;
    in
    checked // {
      inherit name src port urls runtime secrets;
      stateDir = if (m.state or false) then name else null;
      run = req "run";
      preStart = m.preStart or null;
      timers = m.timers or [ ];
      env = m.env or { };
      summary = m.summary or "";
    };

  apps = mapAttrs readManifest cfg.instances;

  # ── turning one manifest into a host ───────────────────────────────────────

  # $SRC, $STATE_DIR and $PORT are the only substitutions a manifest gets.
  # Everything else it writes is passed through verbatim.
  expand = app: value:
    builtins.replaceStrings
      [ "$SRC" "$STATE_DIR" "$PORT" ]
      [ "${app.src}" "/var/lib/${toString app.stateDir}" (toString app.port) ]
      value;

  environmentOf = app:
    (mapAttrs (_: expand app) app.env) // {
      PORT = toString app.port;
    } // optionalAttrs (app.stateDir != null) {
      STATE_DIR = "/var/lib/${app.stateDir}";
    };

  # `run` is the argv after the interpreter, so the manifest never names a
  # binary — only a file inside its own repo.
  command = app: what: suffix:
    pkgs.writeShellApplication {
      name = "${app.name}${suffix}";
      runtimeInputs = [ runtimes.${app.runtime}.pkg ];
      text = ''exec ${runtimes.${app.runtime}.bin} ${app.src}/${what} "$@"'';
    };

  # The same entry point, made usable from a shell on the host. The unit's
  # environment lives in the unit, so the bare wrapper goes looking for the
  # database beside the code in /nix/store and finds nothing — which is exactly
  # what `media-tracker --stats` did until this existed. Needs root in practice:
  # the state directory is 0750 and owned by the app's own user.
  cliOf = app:
    pkgs.writeShellApplication {
      name = app.name;
      runtimeInputs = [ runtimes.${app.runtime}.pkg ];
      text = ''
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList
            (k: v: "export ${k}=${lib.escapeShellArg v}") (environmentOf app))}
        exec ${runtimes.${app.runtime}.bin} ${app.src}/${app.run} "$@"
      '';
    };

  secretName = app: key: "${app.name}-${key}";

  # Shared with every extra unit an app declares (timers), so a warming job
  # cannot quietly hold more privilege than the service it warms.
  hardening = {
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    NoNewPrivileges = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    # AF_UNIX for name resolution, which anything making an outbound request
    # needs; the two INET families to listen and to fetch.
    RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
    RestrictNamespaces = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    SystemCallArchitectures = "native";
  };

  stateConfig = app: optionalAttrs (app.stateDir != null) {
    StateDirectory = app.stateDir;
    StateDirectoryMode = "0750";
  };

  serviceOf = app: {
    description = if app.summary != "" then app.summary else app.name;
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment = environmentOf app;
    serviceConfig = {
      ExecStart = "${command app app.run ""}/bin/${app.name}";
      Restart = "on-failure";
      RestartSec = "5s";
      User = app.name;
      Group = app.name;
      # Read as root at unit start and handed over after the User= drop, which
      # keeps the secret out of the process environment table.
      LoadCredential = map
        (key: "${key}:${config.sops.secrets.${secretName app key}.path}")
        app.secrets;
    }
    // stateConfig app
    // hardening
    // optionalAttrs (app.preStart != null) {
      ExecStartPre = "${command app app.preStart "-prestart"}/bin/${app.name}-prestart";
    };
  };

  # Optional extra oneshots on a timer — the media tracker's cover warmer is
  # the only one so far. Same user, same state directory, same hardening.
  timerUnits = app: map
    (t: {
      name = "${app.name}-${t.name}";
      service = {
        description = t.description or "${app.name}: ${t.name}";
        after = [ "network-online.target" "${app.name}.service" ];
        wants = [ "network-online.target" ];
        environment = environmentOf app;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${command app t.run "-${t.name}"}/bin/${app.name}-${t.name}";
          User = app.name;
          Group = app.name;
        } // stateConfig app // hardening;
      };
      timer = {
        wantedBy = [ "timers.target" ];
        timerConfig = { Persistent = true; } // (t.timer or { });
      };
    })
    app.timers;

  allTimers = concatMap timerUnits (attrValues apps);
in
{
  options.apps.instances = mkOption {
    type = types.attrsOf types.path;
    default = { };
    description = ''
      Projects this host runs, as attribute name → the flake input holding the
      repo. Each must carry an `app.json` at its root; that manifest is what
      generates the unit, user, state directory, firewall rule and tunnel.
    '';
  };

  config = lib.mkIf (apps != { }) {
    users.users = mapAttrs (name: _: {
      isSystemUser = true;
      group = name;
    }) apps;
    users.groups = mapAttrs (_: _: { }) apps;

    # One sops secret per declared key, named `<app>-<key>` in this host's
    # secrets file. The prefix is the boundary: a manifest cannot name a key
    # belonging to another app or to the fleet.
    #
    # restartUnits is load-bearing — LoadCredential snapshots the password at
    # unit start, so rotating the secret without a restart leaves the retired
    # password working while the deploy prints a perfectly normal "Done."
    sops.secrets = builtins.listToAttrs (concatMap
      (app: map
        (key: nameValuePair (secretName app key) {
          sopsFile = ../../../secrets/${config.networking.hostName}.yaml;
          mode = "0400";
          restartUnits = [ "${app.name}.service" ];
        })
        app.secrets)
      (attrValues apps));

    systemd.services =
      (mapAttrs (_: serviceOf) apps)
      // builtins.listToAttrs (map (t: nameValuePair t.name t.service) allTimers);

    systemd.timers =
      builtins.listToAttrs (map (t: nameValuePair t.name t.timer) allTimers);

    # Every app listens on 0.0.0.0 but is reachable only over the tailnet.
    # Public access is cloudflared dialling 127.0.0.1 from inside the host,
    # which needs no rule at all.
    networking.firewall.interfaces.tailscale0.allowedTCPPorts =
      map (app: app.port) (attrValues apps);

    # The URL half of the contract: cf-reconcile creates the tunnel and writes
    # the DNS record before the rebuild ships, from exactly these entries.
    cloudflare.declaredTunnels = builtins.listToAttrs (concatMap
      (app: map
        (url: nameValuePair url { service = "http://localhost:${toString app.port}"; })
        app.urls)
      (attrValues apps));

    # `sudo <app> --stats`, `sudo <app> --warm-covers` and friends from a shell
    # on the host, which is how these were debugged before they had a UI.
    environment.systemPackages = map cliOf (attrValues apps);
  };
}

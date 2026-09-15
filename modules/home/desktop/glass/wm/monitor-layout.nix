{ pkgs, lib, hostConfig, ... }:

# The layout engine every monitor change goes through, and the one place that
# knows how to make reality agree with persisted state.
#
# Rotation and resolution are two front-ends on top of this (rotation.nix,
# resolution.nix). Neither touches hyprctl: they write one state file and call
# `reflow-monitors`. Poking hyprctl directly is what produced the intermediate
# overlaps monitor-layout.py exists to avoid, and the notification per step that
# came with them.
#
# What the planner does and why it is a planner rather than three scripts is
# documented at the top of monitor-layout.py. What matters here is the two
# things that surround it.
#
# ── the ceiling map ────────────────────────────────────────────────────────
# hosts/<h>/hardware/displays.nix declares each output's MAXIMUM mode and its
# resting scale, not the mode it happens to be running. The planner needs that
# declaration to answer "no state file", so it is handed in as JSON through
# $MONITOR_CEILINGS. Deleting an output's state file is how you reset it, and
# without the map the planner would fall back to the live mode and simply pin
# whatever was on screen.
#
# One file, exposed as an option, because three consumers want it: the planner,
# set-monitor-size, and — in its own pre-parsed shape for JS — the bar menu.
# Two writeText calls generating the same JSON is how they drift.
#
# ── the override file ──────────────────────────────────────────────────────
# A nix rebuild reloads hyprland.conf, which re-applies the declared monitor
# lines. When declarations were resting values that was almost always a no-op;
# now that they are ceilings, the declared mode and the running mode are
# expected to differ, so every rebuild would assert 4K and leave the socket2
# watcher below to drag the output back to 1440p — two modesets and a visible
# reshuffle, every time.
#
# So reflow-monitors also writes the layout it computed to
# ~/.config/hypr/monitors.conf, and hyprland.conf sources it. Home-manager emits
# `source=` from `settings` near the TOP of the file, before the `monitor=`
# lines, which is useless here — hence extraConfig, which is appended last. Same
# trick and the same reason as lid.nix; `mkBefore` keeps this source line ahead
# of lid.conf's so a shut lid still has the final word.
#
# The watcher stays as a backstop. With the override file current it has nothing
# to correct, and the planner drops outputs that are already right, so it costs
# a `hyprctl -j monitors` and no modesets. It still earns its place on the one
# rebuild that edits displays.nix itself: the override file then describes the
# old declared geometry, and the watcher is what notices.

let
  planner = ./monitor-layout.py;

  # { "HDMI-A-1": { mode = "3840x2160@144"; scale = "1"; }, … }
  ceilings = pkgs.writeText "monitor-ceilings.json" (builtins.toJSON
    (lib.mapAttrs' (_: m: lib.nameValuePair m.name { inherit (m) mode scale; })
      hostConfig.displays.monitors));

  # The single entry point. Reads persisted state, packs the outputs left to
  # right by effective width, applies mode, transform and position together,
  # and records the result for the next config reload.
  reflow-monitors = pkgs.writeShellApplication {
    name = "reflow-monitors";
    runtimeInputs = with pkgs; [ hyprland python3 xrandr ];
    text = ''
      export MONITOR_CEILINGS=${ceilings}
      python3 ${planner} "$@"

      # Re-assert xrandr primary so XWayland (Proton/Wine games) reads its mode
      # list from the main display rather than whichever output happens to be
      # first. Hyprland resets this whenever outputs are reconfigured.
      xrandr --output ${hostConfig.displays.monitors.external.name} --primary 2>/dev/null || true
    '';
  };

  # Replays persisted state. Identical work to reflow-monitors — kept as its
  # own name because that is what the exec-once and the watcher below call.
  restore-monitor-transforms = pkgs.writeShellApplication {
    name = "restore-monitor-transforms";
    runtimeInputs = [ reflow-monitors ];
    text = ''
      reflow-monitors
    '';
  };

  watcher-script = pkgs.writeShellScript "monitor-transforms-watch" ''
    set -eu
    sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    while [[ ! -S "$sock" ]]; do sleep 0.2; done
    ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$sock" | while IFS= read -r line; do
      case "$line" in
        configreloaded*) ${restore-monitor-transforms}/bin/restore-monitor-transforms ;;
      esac
    done
  '';
in
{
  # Internal, in the sense registry.nix is internal: the front-ends need the
  # derivation, not a copy of it, and re-deriving reflow-monitors per front-end
  # would put two planners in the store and let them drift.
  options.monitorLayout = {
    reflow = lib.mkOption {
      type     = lib.types.package;
      internal = true;
      readOnly = true;
      default  = reflow-monitors;
      description = "The layout engine every monitor front-end delegates to.";
    };

    ceilings = lib.mkOption {
      type     = lib.types.path;
      internal = true;
      readOnly = true;
      default  = ceilings;
      description = "Each declared output's maximum mode and resting scale, as JSON.";
    };
  };

  config = {
    home.packages = [ reflow-monitors restore-monitor-transforms ];

    wayland.windowManager.hyprland.settings.exec-once = [
      "${restore-monitor-transforms}/bin/restore-monitor-transforms"
    ];

    # See the header. mkBefore so lid.conf is sourced after this, not before.
    wayland.windowManager.hyprland.extraConfig = lib.mkBefore ''
      source = ~/.config/hypr/monitors.conf
    '';

    # Seeded empty, never overwritten once it is ours: reflow-monitors owns the
    # content and it is the only record of a runtime choice. The file has to
    # exist regardless, because Hyprland logs a parse error for a `source=` it
    # cannot read, and on a first login nothing has reflowed yet.
    #
    # The marker check is not paranoia. An abandoned 2026-09-02 attempt at this
    # mechanism left a monitors.conf on pod042 pinning HDMI-A-1 to 2560x1440 and
    # eDP-1 to 3640. Nothing sourced it, so it sat there inert for a fortnight —
    # and adding the source line above would have made it live, dropping the
    # panel to 1440p on the next reload with no state file asking for anything.
    # A file this module did not write is not state, it is litter.
    home.activation.initMonitorOverride = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      conf="$HOME/.config/hypr/monitors.conf"
      mkdir -p "$(dirname "$conf")"
      if [ ! -f "$conf" ] || ! grep -q 'Written by reflow-monitors' "$conf"; then
        : > "$conf"
      fi
    '';

    systemd.user.services.monitor-transforms-watcher = {
      Unit = {
        Description = "Restore monitor layout on Hyprland configreloaded";
        PartOf = [ "hyprland-session.target" ];
        After = [ "hyprland-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${watcher-script}";
        Restart = "on-failure";
        RestartSec = "2s";
      };
      Install.WantedBy = [ "hyprland-session.target" ];
    };
  };
}

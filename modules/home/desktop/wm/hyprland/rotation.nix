{ pkgs, hostConfig, ... }:

# Per-monitor rotation, and the layout planner behind it.
#
# State: ~/.local/state/monitor-transforms/<monitor-name>, one file per output
# holding a Hyprland transform (0 landscape, 3 portrait). That directory is the
# only source of truth; `monitor-layout.py` reads it and makes reality match.
#
# Why a planner rather than three scripts each poking hyprctl:
#
# Hyprland re-validates the WHOLE layout after every `keyword monitor`, and
# warns — with a desktop notification — whenever it finds an overlap. Rotating
# one screen changes its effective width, so any arrangement packed tightly
# around it is momentarily wrong. The old code set the transform first, then
# repositioned each output in its own hyprctl call, so a single flip walked
# through several overlapping states and produced one notification per step.
# Six, in practice, on a three-monitor setup.
#
# monitor-layout.py computes the final layout up front and then chooses an
# order to apply it in such that every step lands clear of the monitors that
# have not moved yet — placing left to right when the layout shrinks, right to
# left when it grows, and parking an output far to the right in the rare case
# where neither works. It emits one `hyprctl --batch`. No intermediate state
# ever overlaps, so Hyprland has nothing to complain about.

let
  planner = ./monitor-layout.py;

  # The single entry point. Reads persisted transforms, packs the outputs left
  # to right by effective width, applies transform and position together.
  reflow-monitors = pkgs.writeShellApplication {
    name = "reflow-monitors";
    runtimeInputs = with pkgs; [ hyprland python3 xrandr ];
    text = ''
      python3 ${planner} "$@"

      # Re-assert xrandr primary so XWayland (Proton/Wine games) reads its mode
      # list from the main display rather than whichever output happens to be
      # first. Hyprland resets this whenever outputs are reconfigured.
      xrandr --output ${hostConfig.displays.monitors.external.name} --primary 2>/dev/null || true
    '';
  };

  # Flips one monitor's persisted transform and lets the planner apply it.
  # Deliberately does NOT touch hyprctl itself — doing so is what produced the
  # intermediate overlap the planner exists to avoid.
  rotate-monitor = pkgs.writeShellApplication {
    name = "rotate-monitor";
    runtimeInputs = with pkgs; [ hyprland jq coreutils reflow-monitors ];
    text = ''
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/monitor-transforms"
      mkdir -p "$state_dir"

      if [[ $# -ge 1 ]]; then
        target="$1"
      else
        target=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
      fi

      mon=$(hyprctl -j monitors | jq --arg n "$target" '.[] | select(.name == $n)')
      if [[ -z "$mon" || "$mon" == "null" ]]; then
        echo "rotate-monitor: no monitor named $target" >&2
        exit 1
      fi

      cur_t=$(jq -r '.transform' <<<"$mon")
      if [[ "$cur_t" == "0" ]]; then new_t=3; else new_t=0; fi

      printf '%s' "$new_t" > "$state_dir/$target"
      reflow-monitors
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

  # A nix rebuild reloads hyprland.conf, which re-applies the declared monitor
  # lines and drops any runtime rotation. hosts/<h>/hardware/displays.nix declares the resting
  # orientation so the common case needs no correction at all; this covers the
  # case where the live state differs from it.
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
  home.packages = [ rotate-monitor restore-monitor-transforms reflow-monitors ];

  wayland.windowManager.hyprland.settings = {
    bind = [
      "$mod, backslash, exec, ${rotate-monitor}/bin/rotate-monitor"
    ];
    exec-once = [
      "${restore-monitor-transforms}/bin/restore-monitor-transforms"
    ];
  };

  systemd.user.services.monitor-transforms-watcher = {
    Unit = {
      Description = "Restore monitor transforms on Hyprland configreloaded";
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
}

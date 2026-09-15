{ pkgs, config, ... }:

# Per-monitor rotation. One of two front-ends on the layout engine in
# monitor-layout.nix; resolution.nix is the other.
#
# State: ~/.local/state/monitor-transforms/<monitor-name>, one file per output
# holding a Hyprland transform (0 landscape, 3 portrait). That directory is the
# only source of truth; the planner reads it and makes reality match.
#
# This script deliberately does NOT touch hyprctl itself. Setting the transform
# here and repositioning the neighbours afterwards is what walked the layout
# through several overlapping states and produced one "Monitor <name> overlaps
# with other monitor(s)" notification per step — six, in practice, on this
# three-monitor setup. Flipping a file and calling reflow-monitors produces zero.

let
  reflow = config.monitorLayout.reflow;

  # Flips one monitor's persisted transform and lets the planner apply it.
  rotate-monitor = pkgs.writeShellApplication {
    name = "rotate-monitor";
    runtimeInputs = (with pkgs; [ hyprland jq coreutils ]) ++ [ reflow ];
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
in
{
  home.packages = [ rotate-monitor ];

  wayland.windowManager.hyprland.settings.bind = [
    "$mod, backslash, exec, ${rotate-monitor}/bin/rotate-monitor"
  ];
}

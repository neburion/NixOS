{ pkgs, lib, config, hostConfig, ... }:

# Per-monitor resolution. The second front-end on the layout engine in
# monitor-layout.nix; rotation.nix is the first, and both work the same way —
# write one state file, call reflow-monitors, touch hyprctl never.
#
# State: ~/.local/state/monitor-modes/<monitor-name>, holding a mode string in
# the form the output's own mode list uses, e.g. 2560x1440@144.00.
#
# Two gates, and both matter:
#
#   the mode list  — a mode the panel does not advertise is refused by Hyprland
#                    mid-layout, which leaves every other output repacked around
#                    a monitor that never changed size.
#   the ceiling    — hosts/<h>/hardware/displays.nix declares each output's
#                    maximum. Positions there are computed for it, and it is
#                    also the mode an output with no state file runs at, so
#                    nothing may sit above it.
#
# Choosing the ceiling DELETES the state file rather than writing it. The two
# would behave identically today, but "no file" is the one form that cannot go
# stale if the declaration ever changes.

let
  reflow = config.monitorLayout.reflow;

  ceilings = pkgs.writeText "monitor-ceilings.json" (builtins.toJSON
    (lib.mapAttrs' (_: m: lib.nameValuePair m.name m.mode)
      hostConfig.displays.monitors));

  set-monitor-mode = pkgs.writeShellApplication {
    name = "set-monitor-mode";
    runtimeInputs = (with pkgs; [ hyprland jq coreutils ]) ++ [ reflow ];
    text = ''
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/monitor-modes"

      target="''${1:-}"
      want="''${2:-}"
      if [[ -z "$target" || -z "$want" ]]; then
        echo "usage: set-monitor-mode <output> <WIDTHxHEIGHT@REFRESH>" >&2
        exit 2
      fi

      if [[ ! "$want" =~ ^[0-9]+x[0-9]+@[0-9]+(\.[0-9]+)?$ ]]; then
        echo "set-monitor-mode: '$want' is not a mode (want e.g. 2560x1440@144)" >&2
        exit 2
      fi

      mon=$(hyprctl -j monitors | jq --arg n "$target" '.[] | select(.name == $n)')
      if [[ -z "$mon" || "$mon" == "null" ]]; then
        echo "set-monitor-mode: no monitor named $target" >&2
        exit 1
      fi

      req_res="''${want%@*}"
      req_w="''${req_res%x*}"
      req_h="''${req_res#*x}"
      # Refresh is compared rounded throughout: the same mode is 143.99899 live,
      # 144.00 in the mode list and 144 in displays.nix.
      req_r=$(printf '%.0f' "''${want#*@}")

      ceiling=$(jq -r --arg n "$target" '.[$n] // empty' ${ceilings})
      at_ceiling=0
      if [[ -n "$ceiling" ]]; then
        cap_res="''${ceiling%@*}"
        cap_w="''${cap_res%x*}"
        cap_h="''${cap_res#*x}"
        cap_r=$(printf '%.0f' "''${ceiling#*@}")

        if (( req_w > cap_w || req_h > cap_h || req_r > cap_r )); then
          echo "set-monitor-mode: $want exceeds $target's declared ceiling $ceiling" >&2
          exit 1
        fi
        if (( req_w == cap_w && req_h == cap_h && req_r == cap_r )); then
          at_ceiling=1
        fi
      fi

      # Canonicalise against the output's own list, so the state file always
      # holds a string the planner can match exactly.
      canonical=$(jq -r --arg res "''${req_w}x''${req_h}" --argjson r "$req_r" '
        .availableModes[]
        | sub("Hz$"; "")
        | select(startswith($res + "@"))
        | select(((split("@")[1] | tonumber) | round) == $r)
      ' <<<"$mon" | head -1)

      if [[ -z "$canonical" ]]; then
        echo "set-monitor-mode: $target cannot do $want" >&2
        exit 1
      fi

      mkdir -p "$state_dir"
      if (( at_ceiling )); then
        rm -f "$state_dir/$target"
      else
        printf '%s' "$canonical" > "$state_dir/$target"
      fi

      reflow-monitors
    '';
  };
in
{
  home.packages = [ set-monitor-mode ];
}

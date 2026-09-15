{ pkgs, config, ... }:

# Apparent size, per monitor. The second front-end on the layout engine in
# monitor-layout.nix; rotation.nix is the first, and both work the same way —
# write one state file, call reflow-monitors, touch hyprctl never.
#
# State: ~/.local/state/monitor-modes/<name>, holding a mode and a scale, e.g.
# "3840x2160@144.00 2".
#
# ── why this takes a SIZE and not a mode ───────────────────────────────────
# A fixed-pixel panel interpolates anything that is not a whole-number mapping
# onto its own grid. Asking a 3840x2160 panel for 2560x1440 makes its internal
# scaler stretch by 1.5, so every second pixel is split across two physical ones
# and a 1px glyph stem becomes one pixel plus a half-bright neighbour. Text takes
# it worst, because the app has already antialiased those edges for the smaller
# grid and the scaler then filters the result a second time.
#
# So a smaller desktop is a SCALE at the native mode, never a smaller mode. At
# scale 2 the compositor lays out 1920x1080 logical pixels and renders them into
# all 3840x2160 real ones: identical apparent size to a 1080p signal, glyphs
# rasterised with four times the detail, and no scaler anywhere in the path.
#
# It follows that only whole-number divisors of the native mode are offered at
# all. On a 3840x2160 panel that is 3840x2160, 1920x1080 and 1280x720; 2560x1440
# is 1.5:1 and has no sharp form, so it is not on the menu. The planner enforces
# the same rule independently — see target_scale in monitor-layout.py.
#
# The cost is honest: scale does not reduce what the GPU renders or copies. A
# 1920x1080 logical desktop at scale 2 still pushes 8.29 Mpx per frame, same as
# native. Sharpness was chosen over bandwidth deliberately.
#
# --raw exists for the case this rule forbids: it sets a real mode at scale 1,
# blur included. Nothing in the UI calls it.

let
  reflow   = config.monitorLayout.reflow;
  ceilings = config.monitorLayout.ceilings;

  set-monitor-size = pkgs.writeShellApplication {
    name = "set-monitor-size";
    runtimeInputs = (with pkgs; [ hyprland jq coreutils ]) ++ [ reflow ];
    text = ''
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/monitor-modes"

      raw=0
      if [[ "''${1:-}" == "--raw" ]]; then
        raw=1
        shift
      fi

      target="''${1:-}"
      want="''${2:-}"
      if [[ -z "$target" || -z "$want" ]]; then
        echo "usage: set-monitor-size [--raw] <output> <WIDTHxHEIGHT>" >&2
        exit 2
      fi

      if [[ ! "$want" =~ ^[0-9]+x[0-9]+$ ]]; then
        echo "set-monitor-size: '$want' is not a size (want e.g. 1920x1080)" >&2
        exit 2
      fi

      mon=$(hyprctl -j monitors | jq --arg n "$target" '.[] | select(.name == $n)')
      if [[ -z "$mon" || "$mon" == "null" ]]; then
        echo "set-monitor-size: no monitor named $target" >&2
        exit 1
      fi

      req_w="''${want%x*}"
      req_h="''${want#*x}"

      native=$(jq -r --arg n "$target" '.[$n].mode // empty' ${ceilings})
      if [[ -z "$native" ]]; then
        echo "set-monitor-size: $target is not declared in displays.nix" >&2
        exit 1
      fi
      nat_res="''${native%@*}"
      nat_w="''${nat_res%x*}"
      nat_h="''${nat_res#*x}"

      if (( req_w > nat_w || req_h > nat_h )); then
        echo "set-monitor-size: $want exceeds $target's native $nat_res" >&2
        exit 1
      fi

      if (( raw )); then
        # Escape hatch: a real mode at scale 1, whatever it does to sharpness.
        canonical=$(jq -r --arg res "$want" '
          .availableModes[] | sub("Hz$"; "") | select(startswith($res + "@"))
        ' <<<"$mon" | head -1)
        if [[ -z "$canonical" ]]; then
          echo "set-monitor-size: $target cannot do $want" >&2
          exit 1
        fi
        mkdir -p "$state_dir"
        printf '%s 1' "$canonical" > "$state_dir/$target"
        reflow-monitors
        exit 0
      fi

      # The scale that turns the native mode into the requested size, and it has
      # to come out whole on BOTH axes — a divisor that works across the width
      # and not the height is not a scale, it is a different aspect ratio.
      if (( req_w == 0 || req_h == 0 || nat_w % req_w || nat_h % req_h )); then
        echo "set-monitor-size: $want is not a whole-number divisor of $nat_res" >&2
        exit 1
      fi
      scale=$(( nat_w / req_w ))
      if (( nat_h / req_h != scale )); then
        echo "set-monitor-size: $want is not the aspect of $nat_res" >&2
        exit 1
      fi

      # Resolve the native mode against the output's own list, so the state file
      # holds a string the planner can match exactly.
      nat_r=$(printf '%.0f' "''${native#*@}")
      canonical=$(jq -r --arg res "$nat_res" --argjson r "$nat_r" '
        .availableModes[]
        | sub("Hz$"; "")
        | select(startswith($res + "@"))
        | select(((split("@")[1] | tonumber) | round) == $r)
      ' <<<"$mon" | head -1)

      if [[ -z "$canonical" ]]; then
        echo "set-monitor-size: $target does not advertise its declared $native" >&2
        exit 1
      fi

      mkdir -p "$state_dir"
      if (( scale == 1 )); then
        # Native at scale 1 is what an output with no state file runs at, and
        # "no file" is the one form that cannot go stale if displays.nix changes.
        rm -f "$state_dir/$target"
      else
        printf '%s %s' "$canonical" "$scale" > "$state_dir/$target"
      fi

      reflow-monitors
    '';
  };

  # Insurance. A scale large enough to make the bar hard to use would otherwise
  # leave the menu as the only way back to native, which is circular.
  reset-monitor-size = pkgs.writeShellApplication {
    name = "reset-monitor-size";
    runtimeInputs = (with pkgs; [ hyprland jq coreutils ]) ++ [ reflow ];
    text = ''
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/monitor-modes"

      if [[ $# -ge 1 ]]; then
        target="$1"
      else
        target=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
      fi

      rm -f "$state_dir/$target"
      reflow-monitors
    '';
  };
in
{
  home.packages = [ set-monitor-size reset-monitor-size ];

  wayland.windowManager.hyprland.settings.bind = [
    "$mod SHIFT, backslash, exec, ${reset-monitor-size}/bin/reset-monitor-size"
  ];
}

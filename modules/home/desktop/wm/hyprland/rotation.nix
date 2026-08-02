{ pkgs, hostConfig, ... }:

# Per-monitor rotation. Toggles between landscape (transform 0) and portrait
# (transform 3) on the focused monitor (or a monitor named as arg 1).
# State persists to ~/.local/state/monitor-transforms/<monitor-name>.
#
# After rotating, monitors are reflowed left-to-right (in current x order)
# so no gap opens up when a landscape monitor becomes portrait — otherwise
# the cursor can't cross the dead zone between mismatched-width monitors.
#
# On Hyprland startup (exec-once) and on `configreloaded` events (systemd
# watcher), the restore script re-applies every persisted transform and
# then reflows.

let
  # Reads current monitors, sorts by declared x, lays them out horizontally
  # starting at x=0. Each monitor keeps its declared y. Effective width is
  # (transform in {1,3,5,7} ? height : width) / scale.
  reflow-monitors = pkgs.writeShellApplication {
    name = "reflow-monitors";
    runtimeInputs = with pkgs; [ hyprland jq coreutils gawk xorg.xrandr ];
    text = ''
      set -euo pipefail

      x=0
      hyprctl -j monitors | jq -c 'sort_by(.x)[]' | while read -r mon; do
        name=$(jq -r '.name' <<<"$mon")
        w=$(jq -r '.width' <<<"$mon")
        h=$(jq -r '.height' <<<"$mon")
        rr=$(jq -r '.refreshRate' <<<"$mon" | awk '{printf "%.0f", $1}')
        y=$(jq -r '.y' <<<"$mon")
        scale=$(jq -r '.scale' <<<"$mon")
        transform=$(jq -r '.transform' <<<"$mon")

        case "$transform" in
          1|3|5|7) eff_w=$(awk -v a="$h" -v s="$scale" 'BEGIN{printf "%.0f", a/s}') ;;
          *)       eff_w=$(awk -v a="$w" -v s="$scale" 'BEGIN{printf "%.0f", a/s}') ;;
        esac

        hyprctl keyword monitor \
          "$name,''${w}x''${h}@''${rr},''${x}x''${y},''${scale},transform,''${transform}" \
          >/dev/null
        x=$((x + eff_w))
      done

      # Re-assert xrandr primary so XWayland (Proton/Wine games) reads mode
      # list from the main display, not whichever monitor happens to be first.
      xrandr --output ${hostConfig.displays.monitors.external.name} --primary 2>/dev/null || true
    '';
  };

  rotate-monitor = pkgs.writeShellApplication {
    name = "rotate-monitor";
    runtimeInputs = with pkgs; [ hyprland jq coreutils gawk reflow-monitors ];
    text = ''
      set -euo pipefail

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

      w=$(jq -r '.width' <<<"$mon")
      h=$(jq -r '.height' <<<"$mon")
      rr=$(jq -r '.refreshRate' <<<"$mon" | awk '{printf "%.0f", $1}')
      x=$(jq -r '.x' <<<"$mon")
      y=$(jq -r '.y' <<<"$mon")
      scale=$(jq -r '.scale' <<<"$mon")

      hyprctl keyword monitor \
        "$target,''${w}x''${h}@''${rr},''${x}x''${y},''${scale},transform,''${new_t}" \
        >/dev/null
      printf '%s' "$new_t" > "$state_dir/$target"

      reflow-monitors
    '';
  };

  restore-monitor-transforms = pkgs.writeShellApplication {
    name = "restore-monitor-transforms";
    runtimeInputs = with pkgs; [ hyprland jq coreutils gawk reflow-monitors ];
    text = ''
      set -euo pipefail

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/monitor-transforms"
      [[ -d "$state_dir" ]] || exit 0

      monitors_json=$(hyprctl -j monitors)
      changed=0

      for f in "$state_dir"/*; do
        [[ -f "$f" ]] || continue
        name=$(basename "$f")
        want=$(cat "$f")

        mon=$(jq --arg n "$name" '.[] | select(.name == $n)' <<<"$monitors_json")
        [[ -z "$mon" || "$mon" == "null" ]] && continue

        cur=$(jq -r '.transform' <<<"$mon")
        [[ "$cur" == "$want" ]] && continue

        w=$(jq -r '.width' <<<"$mon")
        h=$(jq -r '.height' <<<"$mon")
        rr=$(jq -r '.refreshRate' <<<"$mon" | awk '{printf "%.0f", $1}')
        x=$(jq -r '.x' <<<"$mon")
        y=$(jq -r '.y' <<<"$mon")
        scale=$(jq -r '.scale' <<<"$mon")

        hyprctl keyword monitor \
          "$name,''${w}x''${h}@''${rr},''${x}x''${y},''${scale},transform,''${want}" \
          >/dev/null
        changed=1
      done

      if [[ "$changed" == "1" ]]; then
        reflow-monitors
      fi
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

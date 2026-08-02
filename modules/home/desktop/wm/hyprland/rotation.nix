{ pkgs, ... }:

# Per-monitor rotation. Toggles between landscape (transform 0) and portrait
# (transform 3) on the focused monitor (or a monitor named as arg 1).
# State persists to ~/.local/state/monitor-transforms/<monitor-name>.
#
# On Hyprland startup (exec-once) and on `configreloaded` events (systemd
# watcher), the restore script re-applies every persisted transform.

let
  rotate-monitor = pkgs.writeShellApplication {
    name = "rotate-monitor";
    runtimeInputs = with pkgs; [ hyprland jq coreutils gawk ];
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
        "$target,''${w}x''${h}@''${rr},''${x}x''${y},''${scale},transform,''${new_t}"
      printf '%s' "$new_t" > "$state_dir/$target"
    '';
  };

  restore-monitor-transforms = pkgs.writeShellApplication {
    name = "restore-monitor-transforms";
    runtimeInputs = with pkgs; [ hyprland jq coreutils gawk ];
    text = ''
      set -euo pipefail

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/monitor-transforms"
      [[ -d "$state_dir" ]] || exit 0

      monitors_json=$(hyprctl -j monitors)

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
          "$name,''${w}x''${h}@''${rr},''${x}x''${y},''${scale},transform,''${want}"
      done
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
  home.packages = [ rotate-monitor restore-monitor-transforms ];

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

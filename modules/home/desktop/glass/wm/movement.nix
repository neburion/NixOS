{ pkgs, ... }:

# Cross-monitor focus and window movement. Hyprland's stock movefocus /
# movewindow only walk the tiling tree; they don't jump to an empty
# neighboring monitor. These wrappers try the native dispatcher first
# and, if nothing changed, fall back to a spatial neighbor lookup.

let
  neighborJq = ''
    def eff:
      if (.transform == 1 or .transform == 3 or .transform == 5 or .transform == 7)
      then {ew: (.width / .scale), eh: (.height / .scale)}
      else {ew: (.width / .scale), eh: (.height / .scale)} end;
    map(. + eff) as $ms
    | ($ms[] | select(.name == $cur)) as $c
    | ($ms | map(select(.name != $cur))) as $others
    | (if $dir == "l" then $others | map(select(.x + .ew <= $c.x + 1)) | sort_by(-(.x))
       elif $dir == "r" then $others | map(select(.x + 1 >= $c.x + $c.ew)) | sort_by(.x)
       elif $dir == "u" then $others | map(select(.y + .eh <= $c.y + 1)) | sort_by(-(.y))
       elif $dir == "d" then $others | map(select(.y + 1 >= $c.y + $c.eh)) | sort_by(.y)
       else [] end)
    | .[0].name // empty
  '';

  hypr-focus = pkgs.writeShellApplication {
    name = "hypr-focus";
    runtimeInputs = with pkgs; [ hyprland jq ];
    text = ''
      set -euo pipefail
      dir="$1"

      old_addr=$(hyprctl -j activewindow | jq -r 'try .address // "none"')
      old_mon=$(hyprctl -j activeworkspace | jq -r '.monitor')

      hyprctl dispatch movefocus "$dir" >/dev/null

      new_addr=$(hyprctl -j activewindow | jq -r 'try .address // "none"')
      new_mon=$(hyprctl -j activeworkspace | jq -r '.monitor')

      if [[ "$old_addr" != "$new_addr" || "$old_mon" != "$new_mon" ]]; then
        exit 0
      fi

      target=$(hyprctl -j monitors | jq -r --arg dir "$dir" --arg cur "$old_mon" '${neighborJq}')
      if [[ -n "$target" ]]; then
        hyprctl dispatch focusmonitor "$target" >/dev/null
      fi
    '';
  };

  hypr-move-window = pkgs.writeShellApplication {
    name = "hypr-move-window";
    runtimeInputs = with pkgs; [ hyprland jq ];
    text = ''
      set -euo pipefail
      dir="$1"

      info=$(hyprctl -j activewindow)
      if [[ "$(jq -r 'type' <<<"$info")" != "object" ]]; then
        exit 0
      fi
      old_at=$(jq -r '"\(.at[0]),\(.at[1])"' <<<"$info")
      old_mon=$(jq -r '.monitor' <<<"$info")

      hyprctl dispatch movewindow "$dir" >/dev/null

      info2=$(hyprctl -j activewindow)
      new_at=$(jq -r '"\(.at[0]),\(.at[1])"' <<<"$info2")
      new_mon=$(jq -r '.monitor' <<<"$info2")

      if [[ "$old_at" != "$new_at" || "$old_mon" != "$new_mon" ]]; then
        exit 0
      fi

      cur_name=$(hyprctl -j activeworkspace | jq -r '.monitor')
      target=$(hyprctl -j monitors | jq -r --arg dir "$dir" --arg cur "$cur_name" '${neighborJq}')
      if [[ -n "$target" ]]; then
        hyprctl dispatch movewindow "mon:$target" >/dev/null
      fi
    '';
  };
in
{
  home.packages = [ hypr-focus hypr-move-window ];

  wayland.windowManager.hyprland.settings.bind = [
    "$mod,       H, exec, ${hypr-focus}/bin/hypr-focus l"
    "$mod,       L, exec, ${hypr-focus}/bin/hypr-focus r"
    "$mod,       K, exec, ${hypr-focus}/bin/hypr-focus u"
    "$mod,       J, exec, ${hypr-focus}/bin/hypr-focus d"
    "$mod SHIFT, H, exec, ${hypr-move-window}/bin/hypr-move-window l"
    "$mod SHIFT, L, exec, ${hypr-move-window}/bin/hypr-move-window r"
    "$mod SHIFT, K, exec, ${hypr-move-window}/bin/hypr-move-window u"
    "$mod SHIFT, J, exec, ${hypr-move-window}/bin/hypr-move-window d"
  ];
}

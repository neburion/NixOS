{ pkgs, ... }:

# tray-launch <sni-id>
#
# Derives a class regex from the SNI id (e.g. spotify-client → [Ss]potify.*),
# focuses a matching Hyprland window if one exists, otherwise runs the id (or
# its prefix) as a command. Used by the tray widget on left click when the
# app's SNI doesn't implement Activate (Spotify, Steam, KeepassXC, ...).

{
  home.packages = [
    (pkgs.writeShellScriptBin "tray-launch" ''
      set -eu
      id="''${1:-}"
      [ -z "$id" ] && exit 0

      key="''${id%%-*}"
      c0="$(printf '%s' "$key" | cut -c1)"
      rest="$(printf '%s' "$key" | cut -c2-)"
      lower="$(printf '%s' "$c0" | tr '[:upper:]' '[:lower:]')"
      upper="$(printf '%s' "$c0" | tr '[:lower:]' '[:upper:]')"
      pat="[$lower$upper]$rest.*"

      if ${pkgs.hyprland}/bin/hyprctl clients -j 2>/dev/null \
          | ${pkgs.gnugrep}/bin/grep -qE "\"class\": ?\"$pat\""; then
          ${pkgs.hyprland}/bin/hyprctl dispatch focuswindow "class:$pat" >/dev/null 2>&1
          exit 0
      fi

      for cmd in "$id" "$key"; do
          if command -v "$cmd" >/dev/null 2>&1; then
              setsid "$cmd" >/dev/null 2>&1 </dev/null &
              exit 0
          fi
      done
    '')
  ];
}

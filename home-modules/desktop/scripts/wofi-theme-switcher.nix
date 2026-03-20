{ pkgs, ... }:

pkgs.writeShellScriptBin "wofi-theme-switcher" ''
  THEMES_DIR="$HOME/.config/wofi/themes"
  CURRENT_STYLE="$HOME/.config/wofi/style.css"

  chosen=$(ls "$THEMES_DIR"/*.css 2>/dev/null \
    | xargs -I{} basename {} .css \
    | wofi --show dmenu --width 300 --height 300 \
           --prompt "Theme:" --cache-file /dev/null)

  [[ -z "$chosen" ]] && exit 0

  src="$THEMES_DIR/$chosen.css"
  [[ -f "$src" ]] && ln -sf "$src" "$CURRENT_STYLE"
''

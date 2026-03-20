{ pkgs, ... }:

pkgs.writeShellScriptBin "wofi-theme-switcher" ''
  THEMES_DIR="$HOME/.config/wofi/themes"
  CURRENT_STYLE="$HOME/.config/wofi/style.css"

  chosen=$(ls "$THEMES_DIR"/*.css 2>/dev/null \
    | xargs -I{} basename {} .css \
    | wofi --show dmenu \
           --prompt ">" \
           --width "35%" \
           --height "30%" \
           --location center \
           --orientation vertical \
           --columns 1 \
           --normal_window \
           --layer overlay \
           --hide_scroll \
           --no_actions \
           --gtk_dark \
           --insensitive=false \
           --hide_search=false \
           --cache-file /dev/null)

  [[ -z "$chosen" ]] && exit 0

  src="$THEMES_DIR/$chosen.css"
  [[ -f "$src" ]] && ln -sf "$src" "$CURRENT_STYLE"
''

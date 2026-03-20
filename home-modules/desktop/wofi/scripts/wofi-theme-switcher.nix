{ pkgs, wofiArgs, ... }:

pkgs.writeShellScriptBin "wofi-theme-switcher" ''
  WOFI_THEMES="$HOME/.config/wofi/themes"
  WAYBAR_THEMES="$HOME/.config/waybar/themes"

  # Create active.css if it doesn't exist yet
  [[ ! -f "$WOFI_THEMES/active.css" ]]   && ln -sf "$WOFI_THEMES/dark.css"   "$WOFI_THEMES/active.css"
  [[ ! -f "$WAYBAR_THEMES/active.css" ]] && ln -sf "$WAYBAR_THEMES/dark.css" "$WAYBAR_THEMES/active.css"

  chosen=$(ls "$WOFI_THEMES"/*.css 2>/dev/null \
    | grep -v active.css \
    | xargs -I{} basename {} .css \
    | wofi --show dmenu ${wofiArgs} --cache-file /dev/null)

  [[ -z "$chosen" ]] && exit 0

  ln -sf "$WOFI_THEMES/$chosen.css"   "$WOFI_THEMES/active.css"
  ln -sf "$WAYBAR_THEMES/$chosen.css" "$WAYBAR_THEMES/active.css"

  # Restart waybar to pick up the new theme
  pkill waybar && waybar &
''

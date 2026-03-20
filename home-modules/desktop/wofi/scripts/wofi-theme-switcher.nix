{ pkgs, wofiArgs, ... }:

pkgs.writeShellScriptBin "wofi-theme-switcher" ''
  THEMES_DIR="$HOME/.config/wofi/themes"
  ACTIVE="$THEMES_DIR/active.css"

  # Create active.css if it doesn't exist yet
  [[ ! -f "$ACTIVE" ]] && ln -sf "$THEMES_DIR/dark.css" "$ACTIVE"

  chosen=$(ls "$THEMES_DIR"/*.css 2>/dev/null \
    | grep -v active.css \
    | xargs -I{} basename {} .css \
    | wofi --show dmenu ${wofiArgs} --cache-file /dev/null)

  [[ -z "$chosen" ]] && exit 0

  src="$THEMES_DIR/$chosen.css"
  [[ -f "$src" ]] && ln -sf "$src" "$ACTIVE"
''

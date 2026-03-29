{ pkgs, wofiArgs, homeDir, ... }:

pkgs.writeShellScriptBin "wofi-theme-switcher" ''
  WOFI_THEMES="$HOME/.config/wofi/themes"
  WAYBAR_THEMES="$HOME/.config/waybar/themes"
  MAKO_THEMES="$HOME/.config/mako/themes"
  MAKO_CONFIG="$HOME/.config/mako/config"

  # Create active.css if it doesn't exist yet
  [[ ! -f "$WOFI_THEMES/active.css" ]]   && ln -sf "$WOFI_THEMES/dark.css"   "$WOFI_THEMES/active.css"
  [[ ! -f "$WAYBAR_THEMES/active.css" ]] && ln -sf "$WAYBAR_THEMES/dark.css" "$WAYBAR_THEMES/active.css"
  [[ ! -f "$MAKO_CONFIG" ]] && rm -f "$MAKO_CONFIG" && cp "$MAKO_THEMES/dark" "$MAKO_CONFIG"

  chosen=$(ls "$WOFI_THEMES"/*.css 2>/dev/null \
    | grep -v active.css \
    | xargs -I{} basename {} .css \
    | wofi --show dmenu ${wofiArgs} --cache-file /dev/null)

  [[ -z "$chosen" ]] && exit 0

  ln -sf "$WOFI_THEMES/$chosen.css"   "$WOFI_THEMES/active.css"
  ln -sf "$WAYBAR_THEMES/$chosen.css" "$WAYBAR_THEMES/active.css"
  rm -f "$MAKO_CONFIG" && cp "$MAKO_THEMES/$chosen" "$MAKO_CONFIG"

  # Map theme name → GTK theme name
  case "$chosen" in
    catppuccin) gtk_theme="catppuccin-mocha-blue-standard" ;;
    gruvbox)    gtk_theme="gruvbox-dark" ;;
    nord)       gtk_theme="Nordic-darker" ;;
    everforest) gtk_theme="Everforest-Dark-B" ;;
    *)          gtk_theme="Adwaita-dark" ;;
  esac

  export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  ${homeDir}/.nix-profile/bin/gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme"
  ${homeDir}/.nix-profile/bin/gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"

  # Restart waybar, reload mako
  pkill waybar && waybar &
  makoctl reload
''

{ pkgs, wofiArgs, homeDir, ... }:

pkgs.writeShellScriptBin "wofi-theme-switcher" ''
  WOFI_THEMES="$HOME/.config/wofi/themes"
  WAYBAR_THEMES="$HOME/.config/waybar/themes"
  MAKO_THEMES="$HOME/.config/mako/themes"
  MAKO_CONFIG="$HOME/.config/mako/config"
  HYPR_THEMES="$HOME/.config/hypr/themes"
  GHOSTTY_THEMES="$HOME/.config/ghostty/themes"

  # Initialize active files if missing
  [[ ! -f "$WOFI_THEMES/active.css" ]]        && ln -sf "$WOFI_THEMES/dark.css"   "$WOFI_THEMES/active.css"
  [[ ! -f "$WAYBAR_THEMES/active.css" ]]       && ln -sf "$WAYBAR_THEMES/dark.css" "$WAYBAR_THEMES/active.css"
  [[ ! -f "$MAKO_CONFIG" ]]                    && cp "$MAKO_THEMES/dark"           "$MAKO_CONFIG"
  [[ ! -e "$HOME/.config/hypr/theme.conf" ]]   && ln -sf "$HYPR_THEMES/dark.conf"  "$HOME/.config/hypr/theme.conf"
  [[ ! -f "$GHOSTTY_THEMES/active.conf" ]]     && echo "theme = dark" > "$GHOSTTY_THEMES/active.conf"

  chosen=$(ls "$WOFI_THEMES"/*.css 2>/dev/null \
    | grep -v active.css \
    | xargs -I{} basename {} .css \
    | wofi --show dmenu ${wofiArgs} --cache-file /dev/null)

  [[ -z "$chosen" ]] && exit 0

  # Wofi + Waybar + Mako
  ln -sf "$WOFI_THEMES/$chosen.css"   "$WOFI_THEMES/active.css"
  ln -sf "$WAYBAR_THEMES/$chosen.css" "$WAYBAR_THEMES/active.css"
  rm -f "$MAKO_CONFIG" && cp "$MAKO_THEMES/$chosen" "$MAKO_CONFIG"

  # Hyprland shadow theme
  ln -sf "$HYPR_THEMES/$chosen.conf" "$HOME/.config/hypr/theme.conf"
  hyprctl reload

  # Ghostty theme
  echo "theme = $chosen" > "$GHOSTTY_THEMES/active.conf"

  # GTK theme
  case "$chosen" in
    catppuccin) gtk_theme="catppuccin-mocha-blue-standard" ;;
    gruvbox)    gtk_theme="gruvbox-dark" ;;
    nord)       gtk_theme="Nordic-darker" ;;
    everforest) gtk_theme="Everforest-Dark-B" ;;
    *)          gtk_theme="Adwaita-dark" ;;
  esac

  export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme"
  ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"

  # Restart waybar, reload mako
  pkill waybar; waybar &
  makoctl reload
''

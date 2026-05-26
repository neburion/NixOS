{ pkgs, lib, wofiArgs, themes, homeDir, ... }:

let
  strip = lib.removePrefix "#";

  # Bake all theme→value mappings at build time from the palette definitions.
  wallpaperDirLines = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: t:
    ''WALLPAPER_DIRS["${name}"]="${t.wallpaperDir or name}"''
  ) themes);

  gtkThemeLines = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: t:
    ''GTK_THEMES["${name}"]="${t.gtkTheme or "Adwaita-dark"}"''
  ) themes);

  fishColorLines = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: t: ''
    FISH_PRIMARY["${name}"]="${strip (t.fishPrimary or "ffffff")}"
    FISH_SECONDARY["${name}"]="${strip (t.fishSecondary or "aaaaaa")}"''
  ) themes);

  # GTK CSS files baked in the nix store (paths are deterministic nix strings).
  css = import ../../gtk-css.nix { inherit pkgs lib themes; };

  gtk4CssLines = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: f:
    ''GTK4_CSS["${name}"]="${f}"''
  ) css.gtk4Files);

  gtk3CssLines = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: f:
    ''GTK3_CSS["${name}"]="${f}"''
  ) css.gtk3Files);
in
pkgs.writeShellScriptBin "wofi-theme-switcher" ''
  WOFI_THEMES="$HOME/.config/wofi/themes"
  WAYBAR_THEMES="$HOME/.config/waybar/themes"
  MAKO_THEMES="$HOME/.config/mako/themes"
  MAKO_CONFIG="$HOME/.config/mako/config"
  HYPR_THEMES="$HOME/.config/hypr/themes"
  GHOSTTY_THEMES="$HOME/.config/ghostty/themes"
  WAYPAPER_CONFIG="$HOME/.config/waypaper/config.ini"

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

  # Wofi + Waybar
  ln -sf "$WOFI_THEMES/$chosen.css"   "$WOFI_THEMES/active.css"
  ln -sf "$WAYBAR_THEMES/$chosen.css" "$WAYBAR_THEMES/active.css"

  # Mako
  rm -f "$MAKO_CONFIG" && cp "$MAKO_THEMES/$chosen" "$MAKO_CONFIG"

  # Hyprland shadow theme
  ln -sf "$HYPR_THEMES/$chosen.conf" "$HOME/.config/hypr/theme.conf"
  hyprctl reload

  # Ghostty theme
  echo "theme = $chosen" > "$GHOSTTY_THEMES/active.conf"

  # GTK theme
  declare -A GTK_THEMES
  ${gtkThemeLines}
  export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface gtk-theme "''${GTK_THEMES[$chosen]:-Adwaita-dark}"
  ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"

  # GTK4 CSS (Nautilus accent/window colors) + GTK3 CSS (nm-applet selection color fix)
  declare -A GTK4_CSS
  ${gtk4CssLines}
  declare -A GTK3_CSS
  ${gtk3CssLines}
  mkdir -p "$HOME/.config/gtk-4.0" "$HOME/.config/gtk-3.0"
  [[ -n "''${GTK4_CSS[$chosen]}" ]] && cp "''${GTK4_CSS[$chosen]}" "$HOME/.config/gtk-4.0/gtk.css"
  [[ -n "''${GTK3_CSS[$chosen]}" ]] && cp "''${GTK3_CSS[$chosen]}" "$HOME/.config/gtk-3.0/gtk.css"

  # Fish prompt colors via universal variables (propagate instantly to all running sessions).
  declare -A FISH_PRIMARY
  declare -A FISH_SECONDARY
  ${fishColorLines}
  ${pkgs.fish}/bin/fish -c "set -U fish_theme_primary ''${FISH_PRIMARY[$chosen]}; set -U fish_theme_secondary ''${FISH_SECONDARY[$chosen]}" 2>/dev/null || true

  # Wallpaper pool: switch to this theme's dedicated folder and pick a random wallpaper.
  declare -A WALLPAPER_DIRS
  ${wallpaperDirLines}

  wallpaper_dir="$HOME/Media/Wallpapers/''${WALLPAPER_DIRS[$chosen]:-$chosen}"

  # Update waypaper config folder
  if [ -f "$WAYPAPER_CONFIG" ]; then
    sed -i "s|^folder = .*|folder = $wallpaper_dir|" "$WAYPAPER_CONFIG"
  fi

  # Pick a random wallpaper from the theme pool and apply it
  wallpaper=$(ls "$wallpaper_dir"/*.{png,jpg,jpeg,gif,webp} 2>/dev/null | shuf | head -1)
  if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
    ${pkgs.swww}/bin/swww img "$wallpaper" --transition-type any
    # Update waypaper's saved wallpaper so --restore works correctly
    if [ -f "$WAYPAPER_CONFIG" ]; then
      sed -i "s|^wallpaper = .*|wallpaper = $wallpaper|" "$WAYPAPER_CONFIG"
    fi
    # Sync to SDDM background
    sddm-update-wallpaper "$wallpaper"
  fi

  # Restart waybar, reload mako
  pkill waybar; waybar &
  makoctl reload
''

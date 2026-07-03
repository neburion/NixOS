{ pkgs, lib, themes, ... }:

# Note: nvim per-PID sockets live in $XDG_RUNTIME_DIR/nvim-theme/*.sock (set up
# by home-modules/cli/neovim/theme.nix luaConfigPost).

let
  inherit (import ../shared-config.nix { inherit lib; }) wofiArgs;

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

  superfileThemeLines = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: t:
    ''SUPERFILE_THEMES_MAP["${name}"]="${t.superfileTheme or name}"''
  ) themes);

  zedThemeLines = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: t:
    ''ZED_THEMES["${name}"]="${t.zedTheme or "One Dark"}"''
  ) themes);

  # GTK CSS files baked in the nix store (paths are deterministic nix strings).
  css = import ../../../theming/gtk/css.nix { inherit pkgs lib themes; };

  gtk4CssLines = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: f:
    ''GTK4_CSS["${name}"]="${f}"''
  ) css.gtk4Files);

  gtk3CssLines = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: f:
    ''GTK3_CSS["${name}"]="${f}"''
  ) css.gtk3Files);
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "wofi-theme-switcher" ''
      WOFI_THEMES="$HOME/.config/wofi/themes"
      WAYBAR_THEMES="$HOME/.config/waybar/themes"
      MAKO_THEMES="$HOME/.config/mako/themes"
      MAKO_CONFIG="$HOME/.config/mako/config"
      HYPR_THEMES="$HOME/.config/hypr/themes"
      GHOSTTY_THEMES="$HOME/.config/ghostty/themes"
      SUPERFILE_THEMES="$HOME/.config/superfile/theme"
      NVIM_THEMES="$HOME/.config/nvf/themes"
      WAYPAPER_CONFIG="$HOME/.config/waypaper/config.ini"

      declare -A SUPERFILE_THEMES_MAP
      ${superfileThemeLines}

      declare -A ZED_THEMES
      ${zedThemeLines}

      # Initialize active files if missing
      [[ ! -f "$WOFI_THEMES/active.css" ]]        && ln -sf "$WOFI_THEMES/dark.css"   "$WOFI_THEMES/active.css"
      [[ ! -f "$WAYBAR_THEMES/active.css" ]]       && ln -sf "$WAYBAR_THEMES/dark.css" "$WAYBAR_THEMES/active.css"
      [[ ! -f "$MAKO_CONFIG" ]]                    && cp "$MAKO_THEMES/dark"           "$MAKO_CONFIG"
      [[ ! -e "$HOME/.config/hypr/theme.conf" ]]   && ln -sf "$HYPR_THEMES/dark.conf"  "$HOME/.config/hypr/theme.conf"
      [[ ! -f "$GHOSTTY_THEMES/active.conf" ]]     && echo "theme = dark" > "$GHOSTTY_THEMES/active.conf"
      [[ ! -e "$NVIM_THEMES/active.lua" ]] && [[ -f "$NVIM_THEMES/dark.lua" ]] && ln -sf "$NVIM_THEMES/dark.lua" "$NVIM_THEMES/active.lua"
      if [[ ! -e "$SUPERFILE_THEMES/active.toml" ]] && [[ -f "$SUPERFILE_THEMES/''${SUPERFILE_THEMES_MAP[dark]:-hacks}.toml" ]]; then
        ln -sf "$SUPERFILE_THEMES/''${SUPERFILE_THEMES_MAP[dark]:-hacks}.toml" "$SUPERFILE_THEMES/active.toml"
      fi

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

      # Ghostty theme — write active.conf, then SIGUSR2 tells running
      # instances to reload their config in place (Ghostty ≥1.2).
      echo "theme = $chosen" > "$GHOSTTY_THEMES/active.conf"
      pkill -SIGUSR2 ghostty 2>/dev/null || true

      # Neovim theme — swap active.lua symlink, then ping any running nvim
      # instance via its per-PID server socket. --remote-expr is async-safe
      # and doesn't disturb the user's current mode.
      if [[ -f "$NVIM_THEMES/$chosen.lua" ]]; then
        ln -sf "$NVIM_THEMES/$chosen.lua" "$NVIM_THEMES/active.lua"
        for sock in "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/nvim-theme/*.sock; do
          [[ -S "$sock" ]] || continue
          nvim --server "$sock" --remote-expr 'execute("ThemeReload")' \
            >/dev/null 2>&1 || true
        done
      fi

      # Superfile theme — symlink active.toml to the mapped palette
      spf_theme="''${SUPERFILE_THEMES_MAP[$chosen]:-$chosen}"
      if [[ -f "$SUPERFILE_THEMES/$spf_theme.toml" ]]; then
        ln -sf "$SUPERFILE_THEMES/$spf_theme.toml" "$SUPERFILE_THEMES/active.toml"
      fi

      # Zed theme — patch .theme.dark in settings.json via jq
      zed_settings="$HOME/.config/zed/settings.json"
      zed_theme="''${ZED_THEMES[$chosen]:-One Dark}"
      if [[ -f "$zed_settings" ]]; then
        tmp=$(mktemp)
        ${pkgs.jq}/bin/jq --arg t "$zed_theme" '.theme.dark = $t' "$zed_settings" > "$tmp" && mv "$tmp" "$zed_settings"
      fi

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
      # install -D handles dir creation; -m 644 overwrites the read-only target
      # left by previous runs (cp would fail with EACCES).
      [[ -n "''${GTK4_CSS[$chosen]}" ]] && install -D -m 644 "''${GTK4_CSS[$chosen]}" "$HOME/.config/gtk-4.0/gtk.css"
      [[ -n "''${GTK3_CSS[$chosen]}" ]] && install -D -m 644 "''${GTK3_CSS[$chosen]}" "$HOME/.config/gtk-3.0/gtk.css"

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
        ${pkgs.awww}/bin/awww img "$wallpaper" --transition-type any
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

      # Nautilus (libadwaita) reads ~/.config/gtk-4.0/gtk.css once at startup and
      # has no live-reload signal. Closing the window isn't enough either: nautilus
      # is a GApplication and stays running in the background, so a fresh window
      # reuses the same cached style provider. `nautilus --quit` is the only way
      # to fully terminate the process so the next launch reads the new CSS.
      nautilus --quit 2>/dev/null || true
    '')
  ];
}

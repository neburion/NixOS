{ pkgs, lib, themes, ... }:

# External consumer sync script — invoked by ThemeState.setActive when a new
# theme is picked. Replaces the write-side of the wofi-theme-switcher script
# now that theme selection lives inside quickshell.
#
# Kept as a shell script (not inline QML Process spawns) because it needs to
# fire ~14 external processes with baked Nix store paths for GTK CSS files;
# doing it in one script is far easier to read and debug.

let
  css = import ./../theming/gtk/css.nix { inherit pkgs lib themes; };

  # Bake per-theme lookup lines: bash arrays keyed by palette name.
  fishColorLines = lib.concatStringsSep "\n  " (lib.mapAttrsToList (name: t: ''
    FISH_PRIMARY["${name}"]="${lib.removePrefix "#" (t.fishPrimary or "#ffffff")}"
    FISH_SECONDARY["${name}"]="${lib.removePrefix "#" (t.fishSecondary or "#aaaaaa")}"''
  ) themes);

  gtkThemeLines = lib.concatStringsSep "\n  " (lib.mapAttrsToList (name: t:
    ''GTK_THEMES["${name}"]="${t.gtkTheme or "Adwaita-dark"}"''
  ) themes);

  gtk4CssLines = lib.concatStringsSep "\n  " (lib.mapAttrsToList (n: f:
    ''GTK4_CSS["${n}"]="${f}"''
  ) css.gtk4Files);

  gtk3CssLines = lib.concatStringsSep "\n  " (lib.mapAttrsToList (n: f:
    ''GTK3_CSS["${n}"]="${f}"''
  ) css.gtk3Files);

  wallpaperDirLines = lib.concatStringsSep "\n  " (lib.mapAttrsToList (name: t:
    ''WALLPAPER_DIRS["${name}"]="${t.wallpaperDir or name}"''
  ) themes);

  superfileThemeLines = lib.concatStringsSep "\n  " (lib.mapAttrsToList (name: t:
    ''SUPERFILE_THEMES_MAP["${name}"]="${t.superfileTheme or name}"''
  ) themes);

  zedThemeLines = lib.concatStringsSep "\n  " (lib.mapAttrsToList (name: t:
    ''ZED_THEMES["${name}"]="${t.zedTheme or "One Dark"}"''
  ) themes);

in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "quickshell-theme-sync";
      runtimeInputs = with pkgs; [ jq glib fish coreutils util-linux awww ];
      text = ''
        # Usage: quickshell-theme-sync <theme-name>
        chosen="''${1:-}"
        if [ -z "$chosen" ]; then
          echo "usage: quickshell-theme-sync <theme-name>" >&2
          exit 2
        fi

        HYPR_THEMES="$HOME/.config/hypr/themes"
        HYPRLOCK_THEMES="$HOME/.config/hypr/hyprlock-themes"
        GHOSTTY_THEMES="$HOME/.config/ghostty/themes"
        SUPERFILE_THEMES="$HOME/.config/superfile/theme"
        NVIM_THEMES="$HOME/.config/nvf/themes"

        declare -A GTK_THEMES; ${gtkThemeLines}
        declare -A GTK4_CSS;   ${gtk4CssLines}
        declare -A GTK3_CSS;   ${gtk3CssLines}
        declare -A FISH_PRIMARY; declare -A FISH_SECONDARY
        ${fishColorLines}
        declare -A WALLPAPER_DIRS;    ${wallpaperDirLines}
        declare -A SUPERFILE_THEMES_MAP; ${superfileThemeLines}
        declare -A ZED_THEMES; ${zedThemeLines}

        # Hyprland shadow theme
        if [ -f "$HYPR_THEMES/$chosen.conf" ]; then
          ln -sf "$HYPR_THEMES/$chosen.conf" "$HOME/.config/hypr/theme.conf"
          ${pkgs.hyprland}/bin/hyprctl reload >/dev/null 2>&1 || true
        fi

        # Hyprlock
        if [ -f "$HYPRLOCK_THEMES/$chosen.conf" ]; then
          ln -sf "$HYPRLOCK_THEMES/$chosen.conf" "$HOME/.config/hypr/hyprlock-theme.conf"
        fi

        # Ghostty — write active.conf then send SIGUSR2 to running instances
        if [ -f "$GHOSTTY_THEMES/$chosen" ]; then
          echo "theme = $chosen" > "$GHOSTTY_THEMES/active.conf"
          pkill -SIGUSR2 ghostty 2>/dev/null || true
        fi

        # Neovim
        if [ -f "$NVIM_THEMES/$chosen.lua" ]; then
          ln -sf "$NVIM_THEMES/$chosen.lua" "$NVIM_THEMES/active.lua"
          for sock in "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/nvim-theme/*.sock; do
            [ -S "$sock" ] || continue
            nvim --server "$sock" --remote-expr 'execute("ThemeReload")' \
              >/dev/null 2>&1 || true
          done
        fi

        # Superfile
        spf_theme="''${SUPERFILE_THEMES_MAP[$chosen]:-$chosen}"
        if [ -f "$SUPERFILE_THEMES/$spf_theme.toml" ]; then
          ln -sf "$SUPERFILE_THEMES/$spf_theme.toml" "$SUPERFILE_THEMES/active.toml"
        fi

        # Zed — patch .theme.dark via jq
        zed_settings="$HOME/.config/zed/settings.json"
        zed_theme="''${ZED_THEMES[$chosen]:-One Dark}"
        if [ -f "$zed_settings" ]; then
          tmp="$(mktemp)"
          jq --arg t "$zed_theme" '.theme.dark = $t | .theme.mode = "dark"' \
            "$zed_settings" > "$tmp" && mv "$tmp" "$zed_settings"
        fi

        # GTK — gsettings + gtk.css install for both GTK4 and GTK3
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
        export DBUS_SESSION_BUS_ADDRESS
        XDG_RUNTIME_DIR="/run/user/$(id -u)"
        export XDG_RUNTIME_DIR
        gsettings set org.gnome.desktop.interface gtk-theme \
          "''${GTK_THEMES[$chosen]:-Adwaita-dark}" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
        if [ -n "''${GTK4_CSS[$chosen]:-}" ]; then
          install -D -m 644 "''${GTK4_CSS[$chosen]}" "$HOME/.config/gtk-4.0/gtk.css"
        fi
        if [ -n "''${GTK3_CSS[$chosen]:-}" ]; then
          install -D -m 644 "''${GTK3_CSS[$chosen]}" "$HOME/.config/gtk-3.0/gtk.css"
        fi

        # Fish prompt colors via universal variables (propagates to all running sessions)
        fish -c "set -U fish_theme_primary ''${FISH_PRIMARY[$chosen]}; set -U fish_theme_secondary ''${FISH_SECONDARY[$chosen]}" \
          2>/dev/null || true

        # Wallpaper — pick a random image from the theme dir, hand to quickshell
        wallpaper_dir="$HOME/Media/Wallpapers/''${WALLPAPER_DIRS[$chosen]:-$chosen}"
        wallpaper="$(find "$wallpaper_dir" -maxdepth 1 \
          -regex '.*\.\(png\|jpg\|jpeg\|gif\|webp\)$' 2>/dev/null | shuf | head -1 || true)"
        if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
          echo "$wallpaper" > "$HOME/.local/state/quickshell/wallpaper"
          cp "$wallpaper" /var/cache/sddm-wallpaper/current 2>/dev/null || true
          pkill mpvpaper 2>/dev/null || true
          awww img "$wallpaper" --transition-type fade 2>/dev/null || true
        fi

        # Spotify — switch spicetify color scheme and re-patch (restarts Spotify).
        if command -v spicetify >/dev/null 2>&1; then
          spicetify config colorscheme "$chosen" >/dev/null 2>&1 || true
          spicetify apply >/dev/null 2>&1 || true
        fi
      '';
    })
  ];
}

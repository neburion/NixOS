{ pkgs, lib, config, themes, ... }:

let
  # Shadow color derived from each theme's background
  mkHyprTheme = c: let
    hex = lib.removePrefix "#" c.bg;
  in ''
    decoration {
        shadow {
            color = rgba(${hex}ee)
        }
    }
  '';
in
{
  # Generate one theme file per palette entry
  xdg.configFile = lib.mapAttrs' (name: colors:
    lib.nameValuePair "hypr/themes/${name}.conf" { text = mkHyprTheme colors; }
  ) themes;

  # Source the runtime-managed active theme (owned by theme-set)
  wayland.windowManager.hyprland.extraConfig = ''
    source = ${config.home.homeDirectory}/.config/hypr/theme.conf
  '';

  # Create theme.conf symlink on first activation; never overwrite
  home.activation.initHyprTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    THEME="$HOME/.config/hypr/theme.conf"
    if [ ! -e "$THEME" ]; then
      mkdir -p "$(dirname "$THEME")"
      ln -sf "$HOME/.config/hypr/themes/dark.conf" "$THEME"
    fi
  '';

  themeHooks.hyprland = pkgs.writeShellScript "theme-hook-hyprland" ''
    theme="$1"
    HYPR_THEMES="$HOME/.config/hypr/themes"
    if [ -f "$HYPR_THEMES/$theme.conf" ]; then
      ln -sf "$HYPR_THEMES/$theme.conf" "$HOME/.config/hypr/theme.conf"
      ${pkgs.hyprland}/bin/hyprctl reload >/dev/null 2>&1 || true
    fi
  '';
}

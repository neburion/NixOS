{ pkgs, lib, config, themes, ... }:

let
  mkGhosttyTheme = c: ''
    background          = ${c.bg}
    foreground          = ${c.fg}
    cursor-color        = ${c.fg}
    selection-background = ${c.selection}
    selection-foreground = ${c.fg}
  '';
in
{
  programs.ghostty = {
    enable = true;
    settings = {
      font-family               = "FiraMono Nerd Font";
      font-size                 = 11;
      cursor-style              = "block";
      shell-integration-features = "no-cursor";
      # Points to the runtime-managed active theme file (owned by theme-set)
      "config-file"             = "${config.home.homeDirectory}/.config/ghostty/themes/active.conf";
    };
  };

  # Generate one theme file per palette entry
  xdg.configFile = lib.mapAttrs' (name: colors:
    lib.nameValuePair "ghostty/themes/${name}" { text = mkGhosttyTheme colors; }
  ) themes;

  # Create active.conf on first activation; never overwrite (switcher owns it)
  home.activation.initGhosttyTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ACTIVE="$HOME/.config/ghostty/themes/active.conf"
    if [ ! -f "$ACTIVE" ]; then
      mkdir -p "$(dirname "$ACTIVE")"
      echo "theme = dark" > "$ACTIVE"
    fi
  '';

  themeHooks.ghostty = pkgs.writeShellScript "theme-hook-ghostty" ''
    theme="$1"
    GHOSTTY_THEMES="$HOME/.config/ghostty/themes"
    if [ -f "$GHOSTTY_THEMES/$theme" ]; then
      echo "theme = $theme" > "$GHOSTTY_THEMES/active.conf"
      ${pkgs.procps}/bin/pkill -SIGUSR2 ghostty 2>/dev/null || true
    fi
  '';
}

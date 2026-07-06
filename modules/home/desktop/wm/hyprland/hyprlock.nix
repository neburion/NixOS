{ lib, themes, ... }:

let
  strip = lib.removePrefix "#";
  rgba  = hex: alpha: "rgba(${strip hex}${alpha})";

  mkThemeConf = t: ''
    background {
        monitor =
        path = screenshot
        blur_passes = 3
        blur_size = 7
        color = ${rgba t.bg "bb"}
        brightness = 0.65
    }

    label {
        monitor =
        text = $TIME
        color = ${rgba t.fg "ff"}
        font_size = 80
        font_family = FiraMono Nerd Font Mono
        position = 0, 160
        halign = center
        valign = center
    }

    label {
        monitor =
        text = cmd[update:60000] date +"%A, %B %d"
        color = ${rgba t.fg "cc"}
        font_size = 16
        font_family = FiraMono Nerd Font Mono
        position = 0, 85
        halign = center
        valign = center
    }

    input-field {
        monitor =
        size = 280, 48
        outline_thickness = 2
        inner_color = ${rgba t.surface "ee"}
        outer_color = ${rgba t.selection "ff"}
        font_color = ${rgba t.fg "ff"}
        check_color = ${rgba t.fg "ff"}
        fail_color = rgba(ff5555ff)
        fail_text = <i>$FAIL ($ATTEMPTS)</i>
        placeholder_text = <i>Password...</i>
        dots_size = 0.25
        dots_spacing = 0.2
        capslock_color = rgba(f38ba8ff)
        position = 0, -40
        halign = center
        valign = center
    }
  '';
in
{
  programs.hyprlock = {
    enable = true;
    settings.general = {
      hide_cursor        = true;
      ignore_empty_input = false;
    };
    extraConfig = ''
      source = ~/.config/hypr/hyprlock-theme.conf
    '';
  };

  xdg.configFile = lib.mapAttrs' (name: t:
    lib.nameValuePair "hypr/hyprlock-themes/${name}.conf" {
      text = mkThemeConf t;
    }
  ) themes;

  home.activation.initHyprlockTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    LINK="$HOME/.config/hypr/hyprlock-theme.conf"
    THEMES="$HOME/.config/hypr/hyprlock-themes"
    HYPR_THEME="$HOME/.config/hypr/theme.conf"
    if [ ! -e "$LINK" ]; then
      if [ -L "$HYPR_THEME" ]; then
        current=$(basename "$(readlink "$HYPR_THEME")" .conf)
        [ -f "$THEMES/$current.conf" ] \
          && ln -sf "$THEMES/$current.conf" "$LINK" \
          || ln -sf "$THEMES/dark.conf" "$LINK"
      else
        ln -sf "$THEMES/dark.conf" "$LINK"
      fi
    fi
  '';
}

{ lib, themes, ... }:

let
  strip = lib.removePrefix "#";
  hex   = color: alpha: "rgba(${strip color}${alpha})";

  mkThemeConf = t: ''
    background {
        monitor     =
        path        = screenshot
        blur_passes = 3
        blur_size   = 6
        brightness  = 0.55
        color       = ${hex t.bg "cc"}
    }

    # ── Central cluster ────────────────────────────────────────────────

    label {
        monitor     =
        text        = cmd[update:0] echo "$USER" | tr '[:lower:]' '[:upper:]'
        color       = ${hex t.fg "ff"}
        font_size   = 13
        font_family = Share Tech Mono
        position    = 0, 128
        halign      = center
        valign      = center
        shadow_passes = 0
    }

    label {
        monitor     =
        text        = ユニット · ロック中
        color       = ${hex t.fg "88"}
        font_size   = 9
        font_family = Noto Sans JP
        position    = 0, 110
        halign      = center
        valign      = center
        shadow_passes = 0
    }

    label {
        monitor     =
        text        = $TIME
        color       = ${hex t.fg "ff"}
        font_size   = 64
        font_family = Share Tech Mono
        position    = 0, 40
        halign      = center
        valign      = center
        shadow_passes = 0
    }

    label {
        monitor     =
        text        = cmd[update:60000] date '+%Y / %m / %d'
        color       = ${hex t.fg "99"}
        font_size   = 10
        font_family = Share Tech Mono
        position    = 0, -16
        halign      = center
        valign      = center
        shadow_passes = 0
    }

    input-field {
        monitor           =
        size              = 300, 36
        position          = 0, -68
        halign            = center
        valign            = center
        outline_thickness = 1
        rounding          = 0
        inner_color       = ${hex t.surface "cc"}
        outer_color       = ${hex t.fg "44"}
        font_color        = ${hex t.fg "ff"}
        check_color       = ${hex t.fg "ff"}
        fail_color        = rgba(cc4444ff)
        fail_text         = <span foreground="#cc4444">AUTHENTICATION FAILED</span>
        fail_transition   = 200
        placeholder_text  = <span foreground="${t.fg}" alpha="40%">&gt;_ authentication required</span>
        dots_size         = 0.22
        dots_spacing      = 0.20
        dots_center       = true
        dots_rounding     = -1
        fade_on_empty     = false
        hide_input        = false
    }

    # ── Corners ────────────────────────────────────────────────────────

    label {
        monitor     =
        text        = cmd[update:0] printf "SESSION LOCKED\nNODE · $USER@$HOSTNAME"
        color       = ${hex t.fg "88"}
        font_size   = 9
        font_family = Share Tech Mono
        position    = 30, -30
        halign      = left
        valign      = top
        shadow_passes = 0
    }

    label {
        monitor     =
        text        = $TIME
        color       = ${hex t.fg "88"}
        font_size   = 9
        font_family = Share Tech Mono
        position    = -30, -30
        halign      = right
        valign      = top
        shadow_passes = 0
    }

    label {
        monitor     =
        text        = cmd[update:0] printf "KERNEL $(uname -r | cut -d- -f1)\nWM · hyprland"
        color       = ${hex t.fg "66"}
        font_size   = 9
        font_family = Share Tech Mono
        position    = 30, 30
        halign      = left
        valign      = bottom
        shadow_passes = 0
    }

    label {
        monitor     =
        text        = cmd[update:0] printf "NIXOS\n$(lspci 2>/dev/null | grep -i 'vga\|3d' | head -1 | sed 's/.*\[\(.*\)\].*/\1/' | cut -c1-16)"
        color       = ${hex t.fg "66"}
        font_size   = 9
        font_family = Share Tech Mono
        position    = -30, 30
        halign      = right
        valign      = bottom
        shadow_passes = 0
    }

    # ── Bottom ticker ──────────────────────────────────────────────────

    label {
        monitor     =
        text        = SYSTEM SCAN · OK  ▸  MEMORY INTEGRITY · VERIFIED  ▸  SESSION LOCKED · SECURE  ▸  NETWORK UPLINK · STABLE  ▸
        color       = ${hex t.fg "44"}
        font_size   = 8
        font_family = Share Tech Mono
        position    = 0, 50
        halign      = center
        valign      = bottom
        shadow_passes = 0
    }
  '';
in
{
  programs.hyprlock = {
    enable = true;
    settings.general = {
      disable_loading_bar = true;
      hide_cursor         = true;
      grace               = 0;
      no_fade_in          = false;
      no_fade_out         = false;
      ignore_empty_input  = false;
      text_trim           = true;
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

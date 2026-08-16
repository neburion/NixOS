{ pkgs, lib, config, themes, ... }:

let
  strip = lib.removePrefix "#";
  hex   = color: alpha: "rgba(${strip color}${alpha})";

  screenDark = import ../hyprland/screen-dark-pkg.nix {
    inherit pkgs;
    homeDirectory = config.home.homeDirectory;
  };

  coverLink = screenDark.coverLink;

  mkThemeConf = t: ''
    background {
        monitor     =
        path        = screenshot
        blur_passes = 3
        blur_size   = 6
        brightness  = 0.55
        color       = ${hex t.bg "cc"}
    }

    # ── Central cluster — identity, time, date, input. Nothing else. ───

    label {
        monitor     =
        text        = cmd[update:0] echo "$USER" | tr '[:lower:]' '[:upper:]'
        color       = ${hex t.fg "ff"}
        font_size   = 13
        font_family = Share Tech Mono
        position    = 0, 118
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
        fail_text         = AUTHENTICATION FAILED
        fail_transition   = 200
        placeholder_text  =
        dots_size         = 0.22
        dots_spacing      = 0.20
        dots_center       = true
        dots_rounding     = -1
        fade_on_empty     = false
        hide_input        = false
    }

    # ── Dark button ────────────────────────────────────────────────────
    #
    # A real click target: hyprlock runs `onclick` as a command. Super+Shift+D
    # does the same thing without aiming (see screen-dark.nix).

    label {
        monitor     =
        text        = [ SCREEN DARK ]
        color       = ${hex t.fg "66"}
        font_size   = 10
        font_family = Share Tech Mono
        position    = 0, -112
        halign      = center
        valign      = center
        onclick     = ${screenDark.script}/bin/screen-dark
        shadow_passes = 0
    }

    # ── Dark cover ─────────────────────────────────────────────────────
    #
    # Normally a transparent PNG, so this draws nothing. screen-dark flips the
    # symlink to an opaque black one and sends SIGUSR2; reload_time = 0 means
    # hyprlock re-reads only on that signal. zindex puts it over every other
    # widget, and 3840px covers the largest panel here from centre.
    #
    # reload_cmd resolves the symlink rather than handing back the same
    # unchanging path: the two covers are distinct store paths, so the value
    # provably differs between states and no path-keyed texture cache can
    # decide the reload is a no-op.

    image {
        monitor     =
        path        = ${coverLink}
        size        = 3840
        border_size = 0
        rounding    = 0
        position    = 0, 0
        halign      = center
        valign      = center
        zindex      = 100
        reload_time = 0
        reload_cmd  = ${pkgs.coreutils}/bin/readlink -f ${coverLink}
    }

    # ── Corner ─────────────────────────────────────────────────────────
    #
    # One line, and it earns its place: which box you are unlocking. The old
    # kernel/GPU/uptime corners and the "SYSTEM SCAN · OK" ticker were props —
    # they never reported anything, so they only competed with the clock.

    label {
        monitor     =
        text        = cmd[update:0] uname -n
        color       = ${hex t.fg "55"}
        font_size   = 9
        font_family = Share Tech Mono
        position    = 30, 30
        halign      = left
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
      # Was true. A hidden pointer can still click, but you cannot aim at the
      # SCREEN DARK button without seeing where it is.
      hide_cursor         = false;
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

  themeHooks.hyprlock = pkgs.writeShellScript "theme-hook-hyprlock" ''
    theme="$1"
    HYPRLOCK_THEMES="$HOME/.config/hypr/hyprlock-themes"
    if [ -f "$HYPRLOCK_THEMES/$theme.conf" ]; then
      ln -sf "$HYPRLOCK_THEMES/$theme.conf" "$HOME/.config/hypr/hyprlock-theme.conf"
    fi
  '';
}

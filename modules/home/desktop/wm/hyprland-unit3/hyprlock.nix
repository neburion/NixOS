{ ... }:

# NieR-styled hyprlock — sepia labels, Share Tech Mono, Japanese subtitle,
# corner infos (SESSION LOCKED / kernel / ARCH LINUX / GPU), bottom ticker,
# static wallpaper background. No animated python bg (per decision #3).

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
      background {
          monitor     =
          path        = ~/Pictures/wallpapers/UDqXyQq.jpeg
          blur_size   = 0
          blur_passes = 0
          brightness  = 1.0
          contrast    = 1.0
          vibrancy    = 0.0
          color       = rgba(11, 9, 6, 1.0)
      }

      input-field {
          monitor         =
          size            = 320, 42
          position        = 0, -60
          halign          = center
          valign          = center

          outline_thickness = 1
          dots_size         = 0.25
          dots_spacing      = 0.20
          dots_center       = true
          dots_rounding     = -1
          outer_color       = rgba(70, 63, 46, 180)
          inner_color       = rgba(214, 207, 181, 12)
          font_color        = rgba(70, 63, 46, 255)
          fade_on_empty     = false
          placeholder_text  = <span foreground="##7a7358" style="italic">mot de passe...</span>
          hide_input        = false
          rounding          = 0
          check_color       = rgba(110, 42, 42, 255)
          fail_color        = rgba(110, 42, 42, 255)
          fail_text         = <span foreground="##6e2a2a">AUTHENTIFICATION ÉCHOUÉE</span>
          fail_transition   = 300
      }

      label {
          monitor     =
          text        = cmd[update:0] echo "$USER" | tr '[:lower:]' '[:upper:]'
          color       = rgba(70, 63, 46, 255)
          font_size   = 13
          font_family = Share Tech Mono
          position    = 0, 80
          halign      = center
          valign      = center
          shadow_passes = 0
      }

      label {
          monitor     =
          text        = ユニット · アクティブ
          color       = rgba(122, 115, 88, 200)
          font_size   = 9
          font_family = Noto Sans JP
          position    = 0, 60
          halign      = center
          valign      = center
          shadow_passes = 0
      }

      label {
          monitor     =
          text        = $TIME
          color       = rgba(70, 63, 46, 255)
          font_size   = 46
          font_family = Share Tech Mono
          position    = 0, 20
          halign      = center
          valign      = center
          shadow_passes = 0
      }

      label {
          monitor     =
          text        = cmd[update:1000] date '+%Y / %m / %d'
          color       = rgba(122, 115, 88, 200)
          font_size   = 9
          font_family = Share Tech Mono
          position    = 0, -4
          halign      = center
          valign      = center
          shadow_passes = 0
      }

      label {
          monitor     =
          text        = cmd[update:0] printf "SESSION LOCKED\nNODE · $USER@$HOSTNAME"
          color       = rgba(70, 63, 46, 220)
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
          color       = rgba(70, 63, 46, 220)
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
          color       = rgba(70, 63, 46, 200)
          font_size   = 9
          font_family = Share Tech Mono
          position    = 30, 30
          halign      = left
          valign      = bottom
          shadow_passes = 0
      }

      label {
          monitor     =
          text        = cmd[update:0] printf "NIXOS\n$(lspci | grep -i 'vga\|3d' | head -1 | sed 's/.*\[\(.*\)\].*/\1/' | cut -c1-16)"
          color       = rgba(70, 63, 46, 200)
          font_size   = 9
          font_family = Share Tech Mono
          position    = -30, 30
          halign      = right
          valign      = bottom
          shadow_passes = 0
      }

      label {
          monitor     =
          text        = SYSTEM SCAN · OK  ▸  MEMORY INTEGRITY · VERIFIED  ▸  SESSION LOCKED · SECURE  ▸  NETWORK UPLINK · STABLE  ▸
          color       = rgba(70, 63, 46, 160)
          font_size   = 8
          font_family = Share Tech Mono
          position    = 0, 50
          halign      = center
          valign      = bottom
          shadow_passes = 0
      }
    '';
  };
}

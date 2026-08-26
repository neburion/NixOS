{ ... }:

# glass hyprlock — one static config, no themes.
#
# The clean version generates a hyprlock-theme.conf per palette, symlinks the
# active one and registers a themeHook to swap it. With a single palette all
# of that machinery collapses into settings written directly, and there is no
# activation script and no hook.
#
# Blurring a screenshot of the desktop is the same move the bar makes, which
# is why the lock screen reads as part of this preset rather than beside it.

{
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        disable_loading_bar = true;
        hide_cursor         = true;
        grace               = 0;
        no_fade_in          = false;
        no_fade_out         = false;
        ignore_empty_input  = false;
        text_trim           = true;
      };

      background = [{
        monitor     = "";
        path        = "screenshot";
        blur_passes = 3;
        blur_size   = 8;
        brightness  = 0.5;
        contrast    = 1.0;
        color       = "rgba(05070Bcc)";
      }];

      label = [
        {
          monitor       = "";
          text          = "$TIME";
          color         = "rgba(EDF0F5ff)";
          font_size     = 68;
          font_family   = "Inter SemiBold";
          position      = "0, 46";
          halign        = "center";
          valign        = "center";
          shadow_passes = 0;
        }
        {
          monitor       = "";
          text          = "cmd[update:60000] date '+%A %d %B'";
          color         = "rgba(EDF0F58f)";
          font_size     = 13;
          font_family   = "Inter";
          position      = "0, -18";
          halign        = "center";
          valign        = "center";
          shadow_passes = 0;
        }
        {
          monitor       = "";
          text          = "cmd[update:0] uname -n";
          color         = "rgba(EDF0F547)";
          font_size     = 10;
          font_family   = "Geist Mono";
          position      = "32, 30";
          halign        = "left";
          valign        = "bottom";
          shadow_passes = 0;
        }
      ];

      input-field = [{
        monitor           = "";
        size              = "300, 42";
        position          = "0, -76";
        halign            = "center";
        valign            = "center";
        outline_thickness = 1;
        rounding          = 21;
        inner_color       = "rgba(12151Ca3)";
        outer_color       = "rgba(FFFFFF1c)";
        font_color        = "rgba(EDF0F5ff)";
        check_color       = "rgba(FFFFFF38)";
        fail_color        = "rgba(FF8A80ff)";
        fail_text         = "Wrong";
        placeholder_text  = "";
        dots_size         = 0.2;
        dots_spacing      = 0.35;
        dots_center       = true;
        dots_rounding     = -1;
        fade_on_empty     = false;
        hide_input        = false;
      }];
    };
  };
}

{ ... }:

# NieR:Automata look — sepia borders, custom "niercurve" bezier,
# tight gaps, no rounding, no blur, no shadow.

{
  wayland.windowManager.hyprland.settings = {
    general = {
      gaps_in               = 4;
      gaps_out              = 8;
      border_size           = 1;
      "col.active_border"   = "rgba(c8b89aee)";
      "col.inactive_border" = "rgba(1a1814aa)";
      layout                = "dwindle";
    };

    decoration = {
      rounding = 0;
      blur.enabled   = false;
      shadow.enabled = false;
    };

    animations = {
      enabled = true;
      bezier    = [ "niercurve, 0.4, 0, 0.2, 1" ];
      animation = [
        "windows,    1, 4, niercurve, slide"
        "windowsOut, 1, 3, niercurve, slide"
        "fade,       1, 4, niercurve"
        "workspaces, 1, 5, niercurve, slidevert"
      ];
    };

    dwindle.preserve_split = true;
    master = {
      new_status = "master";
      mfact      = "0.55";
    };
    misc.disable_hyprland_logo = true;
    xwayland.force_zero_scaling = true;
  };
}

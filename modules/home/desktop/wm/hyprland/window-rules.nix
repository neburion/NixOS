{ ... }:

# Hyprland 0.55 dropped the old flat windowrule syntax; rules now use blocks
# with a mandatory `name` key. The settings.windowrule list generates the old
# format which is silently ignored, so these live in extraConfig instead.

{
  wayland.windowManager.hyprland.extraConfig = ''
    windowrule {
      name  = pip
      float = true
      pin   = true
      move  = 73% 72%
      size  = 426 240
      match:title = ^(Picture-in-Picture)$
    }

    windowrule {
      name   = waypaper
      float  = true
      size   = 800 540
      center = true
      match:class = ^(waypaper)$
    }

  '';
}

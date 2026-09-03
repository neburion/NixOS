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

    # LibreOffice requests fullscreen/maximize when launched from a file
    # manager (Nautilus xdg-activation), popping over whatever's on screen.
    # Suppress those requests so the window opens tiled like any other.
    windowrule {
      name           = libreoffice-suppress-fs
      suppress_event = fullscreen maximize
      match:class    = ^(libreoffice-.*)$
    }

  '';
}

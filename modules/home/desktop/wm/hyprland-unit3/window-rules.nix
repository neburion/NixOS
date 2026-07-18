{ ... }:

# Hyprland 0.55+ block-form rules (mandatory `name` key). Ports the flat
# `windowrule = ... match:class ^(x)$` lines from Unit-3's hyprland.conf.

{
  wayland.windowManager.hyprland.extraConfig = ''
    windowrule {
      name = quickshell
      float = true
      pin   = true
      match:class = ^(quickshell)$
    }

    windowrule {
      name       = spotify
      workspace  = special:spotify
      fullscreen = true
      match:class = ^(Spotify)$
    }

    windowrule {
      name   = qs-yazi-picker
      float  = true
      size   = 900 600
      center = true
      match:class = ^(qs-yazi-picker)$
    }
  '';
}

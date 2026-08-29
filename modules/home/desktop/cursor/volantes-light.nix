{ pkgs, ... }:

# volantes, light variant — a solid white arrow with a swept concave back edge.
# Thin like capitaine but with more shape to it, closer to the macOS pointer.
#
# Nothing imports this. It is here so trying a different pointer is a one-line
# edit in the preset rather than a packaging exercise. See ./phinger-light.nix
# for the softer, heavier option.

let
  name = "volantes_light_cursors";
  size = 15;
in
{
  home.pointerCursor = {
    package = pkgs.volantes-cursors;
    inherit name size;
    gtk.enable = true;
    x11.enable = true;
  };

  wayland.windowManager.hyprland.settings = {
    "$cursorTheme" = name;
    "$cursorSize"  = toString size;
  };
}

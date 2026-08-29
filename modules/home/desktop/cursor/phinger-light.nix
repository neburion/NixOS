{ pkgs, ... }:

# phinger-cursors, light variant — softer and rounder than Bibata, with a
# fatter body and a more diffuse shadow. Also a white-on-dark cursor, so it
# suits the same desktops; swap the import if Bibata reads too sharp.
#
# Nothing imports this today. It exists so that changing the pointer is the
# same one-line edit as changing the terminal or the GTK theme.

let
  name = "phinger-cursors-light";
  size = 15;
in
{
  home.pointerCursor = {
    package = pkgs.phinger-cursors;
    inherit name size;
    gtk.enable = true;
    x11.enable = true;
  };

  wayland.windowManager.hyprland.settings = {
    "$cursorTheme" = name;
    "$cursorSize"  = toString size;
  };
}

{ pkgs, ... }:

# Adwaita pointer — the stock GNOME cursor, and what every preset used before
# cursors got their own module. Kept as the default for the presets that are
# built around GNOME's icon and GTK themes, where it is the matching piece
# rather than the odd one out.

let
  name = "Adwaita";
  size = 24;
in
{
  home.pointerCursor = {
    package = pkgs.adwaita-icon-theme;
    inherit name size;
    gtk.enable = true;
    x11.enable = true;
  };

  wayland.windowManager.hyprland.settings = {
    "$cursorTheme" = name;
    "$cursorSize"  = toString size;
  };
}

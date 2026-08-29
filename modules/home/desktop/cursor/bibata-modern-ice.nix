{ pkgs, ... }:

# Bibata Modern Ice — white fill, thin dark outline, rounded corners.
#
# Picked for glass because it is the only part of the pointer that has to
# agree with anything: the shell's text is #E8EAEC on a near-black ground, and
# a white cursor with a hairline outline is the same drawing. Adwaita's is a
# heavier, squarer arrow with a grey body, which is why it started reading as
# borrowed from another desktop once the rest of the preset changed.
#
# Size is unchanged at 15. The complaint was that the cursor looked out of
# place, not that it was the wrong size, and 15 is what has been in use.

let
  name = "Bibata-Modern-Ice";
  size = 15;
in
{
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    inherit name size;
    gtk.enable = true;
    x11.enable = true;
  };

  wayland.windowManager.hyprland.settings = {
    "$cursorTheme" = name;
    "$cursorSize"  = toString size;
  };
}

{ pkgs, ... }:

# Borealis — hairline outlines, dark fill, one drawing style held across the
# whole set.
#
# The set is the point, not the arrow. Earlier picks were chosen on the arrow
# alone and fell apart everywhere else: WhiteSur pairs a clean pointer with a
# rainbow pinwheel for busy and an orange badge for help, Posy does the same
# with a rainbow ribbon and a red X, capitaine hangs orange dots off its resize
# arrows. Borealis draws arrow, link, text, busy, no-drop, resize, move and
# help in the same hairline outline, which is what makes it read as a theme
# rather than as eight unrelated icons.
#
# GPL-3.0, from gnome-look. Nothing here needs allowUnfree, unlike the
# apple-cursor round.
#
# Size 24 — the X default. This repo carried 15 from before cursors had their
# own module, which is why every theme tried at that value read as undersized
# no matter how it was drawn.

let
  name = "Borealis-cursors";
  size = 24;
in
{
  home.pointerCursor = {
    package = pkgs.borealis-cursors;
    inherit name size;
    gtk.enable = true;
    x11.enable = true;
  };

  wayland.windowManager.hyprland.settings = {
    "$cursorTheme" = name;
    "$cursorSize"  = toString size;
  };
}

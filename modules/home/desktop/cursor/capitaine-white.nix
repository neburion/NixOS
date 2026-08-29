{ pkgs, ... }:

# Capitaine, white variant — a thin, sharp, hollow arrow with no rounding
# anywhere.
#
# Chosen for glass because it is drawn the way the rest of the preset is: 1px
# hairline strokes, Material Symbols at weight 300, nothing with a fat outline
# or a soft corner. Bibata Modern Ice was tried here first and was too rounded
# and too heavy — it read as a toy next to the shell.
#
# Size stays 15, unchanged since before cursors had their own module.

let
  name = "capitaine-cursors-white";
  size = 15;
in
{
  home.pointerCursor = {
    package = pkgs.capitaine-cursors;
    inherit name size;
    gtk.enable = true;
    x11.enable = true;
  };

  wayland.windowManager.hyprland.settings = {
    "$cursorTheme" = name;
    "$cursorSize"  = toString size;
  };
}

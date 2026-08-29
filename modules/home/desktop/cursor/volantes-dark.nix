{ pkgs, ... }:

# volantes, dark variant — grey fill, white outline, swept concave back edge.
# Apple-adjacent rather than Apple: more stylised than ./macos.nix, and lighter
# in the body, so it sits a shade softer against a dark desktop.
#
# Nothing imports this. It is the free alternative to ./macos.nix, and it is
# here so that changing the pointer stays a one-line edit in the preset.

let
  name = "volantes_cursors";
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

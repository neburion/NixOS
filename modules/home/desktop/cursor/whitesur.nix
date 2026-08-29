{ pkgs, ... }:

# WhiteSur — the macOS Big Sur pointer: dark fill, white outline, a proper
# taper and a tail.
#
# Fourth pick for glass, so the misses are worth recording. Bibata Modern Ice
# was rounded and heavy enough to read as a toy. capitaine white had the right
# weight and the wrong colour. apple-cursor's `macOS` is Apple's literal
# artwork and looked harsh — straight edges, blunt taper, no softening
# anywhere. WhiteSur is the same silhouette drawn with a curve in it, which is
# the part that was missing.
#
# It is also free (GPL, from the WhiteSur theme project), where apple-cursor is
# unfree and redistributes Apple's own files. Nothing here depends on
# allowUnfree any more.
#
# Size is 24, not the 15 this repo carried since before cursors had their own
# module. 15 is well under the X default and every theme tried at that value
# read as undersized; 24 is the default for a reason.

let
  name = "WhiteSur-cursors";
  size = 24;
in
{
  home.pointerCursor = {
    package = pkgs.whitesur-cursors;
    inherit name size;
    gtk.enable = true;
    x11.enable = true;
  };

  wayland.windowManager.hyprland.settings = {
    "$cursorTheme" = name;
    "$cursorSize"  = toString size;
  };
}

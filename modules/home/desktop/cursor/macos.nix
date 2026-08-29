{ pkgs, ... }:

# apple-cursor's `macOS` theme — black fill, crisp white outline, straight
# edges, sharp tip. The actual Apple pointer, not an approximation of one.
#
# Two earlier picks for glass missed in opposite directions: Bibata Modern Ice
# was rounded and heavy enough to read as a toy, and capitaine white was the
# right weight but the wrong colour. This is black, which keeps the pointer
# reading as an object on top of the desktop rather than as another light
# element in a shell already made of them.
#
# Note on licence: apple-cursor is unfree — it redistributes Apple's cursor
# artwork. It builds here because modules/system/nixos.nix and flake.nix both
# set allowUnfree, which this repo already relies on for Spotify and others; no
# policy changed to accommodate it. ./volantes-dark.nix is the free
# Apple-adjacent option if that ever matters.
#
# Size stays 15, unchanged since before cursors had their own module.

let
  name = "macOS";
  size = 15;
in
{
  home.pointerCursor = {
    package = pkgs.apple-cursor;
    inherit name size;
    gtk.enable = true;
    x11.enable = true;
  };

  wayland.windowManager.hyprland.settings = {
    "$cursorTheme" = name;
    "$cursorSize"  = toString size;
  };
}

{ pkgs, ... }:

# phinger, dark variant — outlined arrow with a tail, thinner and rounder than
# ./whitesur.nix, and grey rather than black in the body.
#
# Nothing imports this. It was the runner-up to WhiteSur and is kept so that
# changing the pointer stays a one-line edit in the preset.

let
  name = "phinger-cursors-dark";
  size = 24;
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

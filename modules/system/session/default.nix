{ ... }:

# Everything a graphical login needs before a desktop preset can run.
#
# Nothing here decides how anything looks — that is the preset's job, and it
# lives entirely under modules/home/desktop/. This is the display stack: a
# greeter, a compositor the greeter can start, portals, fonts, and the two
# package managers whose payload is GUI applications.
#
# Replaces the old modules/system/desktop/ tree, which mirrored
# modules/home/desktop/ in name only. They were never the same concern — one is
# a display stack, the other is a rice — and the shared name is why both grew a
# desktop/ meaning different things.

{
  imports = [
    ./dconf.nix
    ./flatpak.nix
    ./fonts.nix
    ./hyprland.nix
    ./sddm.nix
    ./steam.nix
    ./wayland-env.nix
    ./xdg-portal.nix
  ];
}

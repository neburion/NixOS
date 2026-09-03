{ ... }:

# What a graphical login needs before any desktop is chosen: a greeter, the
# portal plumbing, the Wayland environment, and dconf for the GTK stack.
#
# Nothing here decides how anything looks, and nothing here is a program.
# What left, and where it went:
#
#   hyprland.nix  → each preset's wm/system.nix   the compositor is the rice's
#   fonts.nix     → each preset's fonts/          faces belong to what renders
#   steam.nix     → gaming/launchers/steam/       a store, not a prerequisite
#   flatpak.nix   → cli/flatpak/system.nix        a package manager
#
# All four were filed here because they needed a NixOS option, not because a
# graphical login needs them.

{
  imports = [
    ./dconf.nix
    ./sddm.nix
    ./wayland-env.nix
    ./xdg-portal.nix
  ];
}

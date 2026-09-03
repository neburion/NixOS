{ ... }:

# What a graphical login needs before a desktop is chosen. The desktop itself
# is a home preset; this is only the stack underneath it.

{
  imports = [
    ../session/dconf.nix
    ../session/sddm.nix
    ../session/wayland-env.nix
    ../session/xdg-portal.nix
  ];
}

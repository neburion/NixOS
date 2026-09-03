{ ... }:

# System-level fish enable. Required when a user's login shell is
# pkgs.fish — NixOS refuses to accept a shell that isn't enabled here.
# Import from the user manifest, not from a host.

{
  programs.fish.enable = true;
}

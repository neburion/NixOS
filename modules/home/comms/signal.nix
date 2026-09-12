{ pkgs, ... }:

# Pulled from `unstable` on purpose. Signal's servers hard-expire clients a
# few months after release — the app refuses to start and tells you to
# upgrade, with no override. The release channel's pin can sit far enough
# behind for that to happen mid-cycle, so the flake pin is the update path:
# `nix flake update nixpkgs-unstable` when it starts nagging.

{
  home.packages = with pkgs; [
    unstable.signal-desktop
  ];
}

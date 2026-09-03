{ pkgs, ... }:

# osu!lazer — the current client. `-bin` is the upstream AppImage rather than
# the source build: same version, but it ships the exact binaries peppy signs,
# which is what the official server's version check expects.
#
# Pulled from `unstable` on purpose. lazer talks to a live server that refuses
# clients more than a few releases old, and the release channel's pin drifts
# months behind; a stale osu! is a game that won't log in. The AppImage's own
# self-updater is a no-op under Nix, so the flake pin *is* the update path —
# `nix flake update nixpkgs-unstable` when it starts complaining.

{
  home.packages = with pkgs; [
    unstable.osu-lazer-bin
  ];
}

{ pkgs, config, ... }:

# Ensure the flathub remote exists at user scope so per-user flatpak
# apps (see modules/home/gaming/launchers/sober.nix and any future home-scope
# flatpaks) can install without sudo.
#
# Absolute store path, not a bare `flatpak`: the activation script's PATH does
# not carry it, and the `|| true` would hide the failure.

{
  home.activation.flatpakSetup =
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.flatpak}/bin/flatpak remote-add --user --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo || true
    '';
}

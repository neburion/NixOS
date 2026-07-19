{ pkgs, config, ... }:

# Ensure the flathub remote exists at user scope so per-user flatpak
# apps (see modules/home/gaming/sober.nix and any future home-scope
# flatpaks) can install without sudo.

{
  home.activation.flatpakSetup =
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      flatpak remote-add --user --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo || true
    '';
}

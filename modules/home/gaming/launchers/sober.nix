{ config, ... }:

# Sober — Roblox launcher for Linux (proprietary, AppImage upstream).
# Not in nixpkgs; not on any known community flake. Installed
# declaratively as a user-scope flatpak instead of wrapping the raw
# AppImage, so Sober's own auto-update via flathub keeps working.
#
# Requires the flathub remote at user scope: see
# modules/home/cli/packager/flatpak.nix (runs before this via the
# named DAG dependency).

{
  home.activation.installSober =
    config.lib.dag.entryAfter [ "flatpakSetup" ] ''
      flatpak install --user --assumeyes --or-update \
        flathub org.vinegarhq.Sober || true
    '';
}

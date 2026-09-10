{ pkgs, helium, ... }:

# Helium — Chromium with the Google removed: no telemetry, no Safe Browsing
# phone-home, no component updater. Installed beside Zen rather than replacing
# it; a Chromium engine is worth having around for the sites Gecko renders
# badly, and this is the one that does not report back.
#
# The package is a repack of upstream's release tarball, so it self-updates
# never. Moving version is `nix flake update helium`.

{
  home.packages = [
    helium.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}

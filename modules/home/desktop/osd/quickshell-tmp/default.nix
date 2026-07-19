{ ... }:

# Quickshell on-screen display: volume and brightness overlays.
# Audio service lives in quickshell/core (shared with bar).
# BrightnessState lives here — only OSD uses it.

{
  imports = [
    ../../quickshell-shared/core.nix
    ./volume.nix
    ./brightness.nix
  ];
}

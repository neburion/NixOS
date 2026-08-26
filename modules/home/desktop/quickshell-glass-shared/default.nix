{ ... }:

# Shared infrastructure for the glass preset. Imported by every glass component
# module. The NixOS module system deduplicates this path, so importing
# bar/quickshell-glass AND launcher/quickshell-glass only applies it once.
#
# Mirrors quickshell-shared/core.nix, which it pulls in — the difference is
# that glass components read Common/Glass.qml (literal tokens) instead of
# Common/Theme.qml (ThemeState-reactive palettes). Theme.qml is still generated
# by core.nix; nothing here imports it.

{
  imports = [
    ../quickshell-shared/core.nix
    ./palette.nix
    ./hypr-ipc.nix
    ./surface.nix
    ./wallpaper-state.nix
    ./accent.nix
  ];
}

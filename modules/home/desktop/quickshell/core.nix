{ ... }:

# Shared quickshell infrastructure. Imported by every quickshell component
# module. The NixOS module system deduplicates this path, so importing
# bar/quickshell AND launcher/quickshell only applies core once.

{
  imports = [
    ./package.nix
    ./registry.nix
    ./shell.nix
    ./themes.nix
    ./theme-sync.nix
    ./services/theme-state.nix
    ./services/audio.nix
  ];
}

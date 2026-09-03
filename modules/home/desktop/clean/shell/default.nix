{ ... }:

# Clean's Quickshell machinery. Imported by every clean surface; the module
# system deduplicates the path, so two surfaces importing it apply it once.
#
# This was modules/home/desktop/quickshell-shared/, a parent shared by three
# presets. It is now owned by one, and glass carries its own copy. That
# duplication is DESIGN.md §6: a shared parent is precisely the arrangement
# that lets editing one preset break another, and it is what the rule "nothing
# crosses out of desktop/<preset>/" exists to prevent.
#
# registry.nix is the piece to watch: its options are `lines`-typed, so two
# modules contributing the same key concatenate rather than conflict, and
# Quickshell dies at the seam with a syntax error. Confined to one preset now.

{
  imports = [
    ./package.nix
    ./registry.nix
    ./shell.nix
    ./themes.nix
    ./services/audio.nix
    ./services/monitor-rotation.nix
    ./services/theme-state.nix
  ];
}

{ ... }:

# Glass's Quickshell machinery. Imported by every glass surface; the module
# system deduplicates the path, so bar/ and launcher/ both importing it applies
# it once.
#
# This is a copy of what used to be quickshell-shared/ plus quickshell-glass-
# shared/, and the duplication against clean/shell/ is the design, not debt.
# Those two directories were shared parents for three sibling presets, which is
# the arrangement that guarantees editing one preset can break another — and
# they are what DESIGN.md §6 and the rule that nothing crosses out of
# desktop/<preset>/ exist to prevent. A fix here is not a fix in clean/. That
# is the accepted cost of presets being free to diverge.
#
# registry.nix is the piece to be careful with: its options are `lines`-typed,
# so two modules contributing the same key concatenate instead of conflicting,
# and Quickshell dies at the seam with a syntax error. Now that each preset
# owns its own registry, that can only happen within one preset.

{
  imports = [
    # No themes.nix and no ThemeState service. Both generated the palette
    # table and the reactive singleton that Common/Theme.qml needs, and glass
    # reads Common/Glass.qml — literal tokens, deliberately not reactive. They
    # were carried along only because the shared layer bundled them.
    ./package.nix
    ./registry.nix
    ./shell.nix
    ./services/audio.nix
    ./services/monitor-rotation.nix

    # The glass layer: literal tokens and a per-output wallpaper, rather than
    # the palette-switching Theme.qml the other preset uses. The palette itself
    # sits at the preset root as its own slot, but is imported here so that a
    # surface importing ../shell gets a complete shell.
    ../palette.nix
    ./surface.nix
    ./wallpaper-state.nix
    ./accent.nix
    ./hypr-ipc.nix
  ];
}

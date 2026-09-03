{ ... }:

# glass hyprland. Same as the base except:
#   - ../hyprland/themes.nix is NOT imported. That module generates a
#     per-palette hypr/themes/<name>.conf, symlinks theme.conf, sources it and
#     registers a themeHook. With one fixed palette there is nothing to switch,
#     so the shadow colour is a literal in looks.nix instead.
#   - keybinds, looks, auto-exec and hyprlock are forked (see each file).
#   - layer-rules.nix is new: it is what makes the shell translucent rather
#     than merely transparent.
#   - window-opacity.nix is new: the same job for windows that cannot paint
#     their own transparency (Spotify).

{
  # Every file is this preset's own. It used to cherry-pick eleven of these out
  # of a sibling ../hyprland/ directory that nothing imported as a unit — a
  # shared layer wearing a directory's name, and the hardest of the three to
  # spot precisely because it was not called "shared".
  #
  # themes.nix is the one base file NOT copied across: it generates a
  # per-palette hypr/themes/<name>.conf and registers a theme hook, and with one
  # fixed palette there is nothing to switch. The shadow colour is a literal in
  # looks.nix instead.
  imports = [
    ./auto-exec.nix
    ./enable.nix
    ./env.nix
    ./hyprlock.nix
    ./input.nix
    ./keybinds.nix
    ./layer-rules.nix
    ./lid.nix
    ./looks.nix
    ./monitors.nix
    ./movement.nix
    ./programs.nix
    ./rotation.nix
    ./screenshot-tools.nix
    ./session.nix
    ./window-opacity.nix
    ./window-rules.nix
  ];
}

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
  imports = [
    ./auto-exec.nix
    ../hyprland/enable.nix
    ../hyprland/env.nix
    ./hyprlock.nix
    ../hyprland/input.nix
    ./keybinds.nix
    ./layer-rules.nix
    ../hyprland/lid.nix
    ../hyprland/monitors.nix
    ../hyprland/movement.nix
    ../hyprland/programs.nix
    ../hyprland/rotation.nix
    ../hyprland/screenshot-tools.nix
    ../hyprland/session.nix
    ../hyprland/window-rules.nix
    ./looks.nix
    ./window-opacity.nix
  ];
}

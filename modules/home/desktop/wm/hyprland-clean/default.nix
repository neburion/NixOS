{ ... }:

# clean hyprland: same as base but swaps looks.nix for clean-specific
# animations (faster horizontal slide, easeInOutQuint bezier).

{
  imports = [
    ../hyprland/auto-exec.nix
    ../hyprland/enable.nix
    ../hyprland/env.nix
    ./hyprlock.nix
    ../hyprland/input.nix
    ../hyprland/keybinds.nix
    ../hyprland/lid.nix
    ../hyprland/monitors.nix
    ../hyprland/movement.nix
    ../hyprland/programs.nix
    ../hyprland/rotation.nix
    ../hyprland/screenshot-tools.nix
    ../hyprland/session.nix
    ../hyprland/themes.nix
    ../hyprland/window-rules.nix
    ./looks.nix
  ];
}

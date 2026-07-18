{ ... }:

# NieR hyprland: same as base but swaps looks.nix for nier-specific
# animations (faster horizontal slide, niercurve bezier).

{
  imports = [
    ../hyprland/auto-exec.nix
    ../hyprland/enable.nix
    ../hyprland/env.nix
    ./hyprlock.nix
    ../hyprland/input.nix
    ../hyprland/keybinds.nix
    ../hyprland/monitors.nix
    ../hyprland/programs.nix
    ../hyprland/screenshot-tools.nix
    ../hyprland/session.nix
    ../hyprland/themes.nix
    ../hyprland/window-rules.nix
    ./looks.nix
  ];
}

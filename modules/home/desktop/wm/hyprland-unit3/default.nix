{ ... }:

# Unit-3 hyprland preset: reuse YOUR existing behavior modules (env, input,
# monitors, session, programs, keybinds, screenshot-tools, auto-exec, enable)
# and swap in NieR-flavored looks/window-rules/hyprlock plus the SUPER+Tab
# ControlCenter bind. themes.nix (per-palette shadow overrides) is dropped
# because Unit-3's aesthetic is fixed sepia.

{
  imports = [
    ../hyprland/enable.nix
    ../hyprland/env.nix
    ../hyprland/input.nix
    ../hyprland/keybinds.nix
    ../hyprland/monitors.nix
    ../hyprland/programs.nix
    ../hyprland/screenshot-tools.nix
    ../hyprland/session.nix
    ../hyprland/auto-exec.nix

    ./looks.nix
    ./window-rules.nix
    ./hyprlock.nix
    ./extra-binds.nix
  ];
}

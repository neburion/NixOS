{ ... }:

# clean hyprland: same as base but swaps looks.nix for clean-specific
# animations (faster horizontal slide, easeInOutQuint bezier).

{
  imports = [
    ./auto-exec.nix
    ./enable.nix
    ./env.nix
    ./hyprlock.nix
    ./input.nix
    ./keybinds.nix
    ./lid.nix
    ./looks.nix
    ./monitors.nix
    ./movement.nix
    ./programs.nix
    ./rotation.nix
    ./screenshot-tools.nix
    ./session.nix
    ./themes.nix
    ./window-rules.nix
  ];
}

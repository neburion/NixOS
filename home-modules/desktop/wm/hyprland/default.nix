{ pkgs, ... }:

{
  imports = [
    ./programs.nix
    ./auto-exec.nix
    ./keybinds.nix
    ./monitors.nix
    ./looks.nix
    ./env.nix
    ./themes.nix
    ./session.nix
  ];

  wayland.windowManager.hyprland.enable = true;
}

{ pkgs, ... }:

{
  imports = [
    ./programs.nix
    ./auto-exec.nix
    ./keybinds.nix
    ./monitors.nix
    ./looks.nix
    ./env.nix
  ];

  home.packages = with pkgs; [ hyprlock ];
  wayland.windowManager.hyprland.enable = true;
}

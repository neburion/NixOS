{ ... }:

{
  imports = [
    ./programs.nix
    ./auto-exec.nix
    ./keybinds.nix
    ./monitors.nix
    ./looks.nix
    ./env.nix
  ];

  wayland.windowManager.hyprland.enable = true;
}

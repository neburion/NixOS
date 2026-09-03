{ pkgs, ... }:

# Per-monitor wallpaper picker.
#
# WallpaperState and the glass-wallpaper / glass-accent scripts live in
# quickshell-glass-shared, because the bar needs the accent whether or not the
# picker is imported. This module is only the picker UI.

{
  imports = [
    ../shell
    ./picker.nix
  ];

  home.packages = with pkgs; [ awww mpvpaper ];

  wayland.windowManager.hyprland.settings."$wallpaperManager" = "qs ipc call wallpaperPicker toggle";
}

{ ... }:

# Quickshell wallpaper picker. WallpaperState service lives here — only the
# picker uses it. Sets $wallpaperManager for keybinds.nix.

{
  imports = [
    ../../quickshell-shared/core.nix
    ../awww
    ./picker.nix
  ];

  wayland.windowManager.hyprland.settings."$wallpaperManager" =
    "qs ipc call wallpaperPicker toggle";
}

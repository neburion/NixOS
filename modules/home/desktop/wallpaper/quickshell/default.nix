{ ... }:

# Quickshell wallpaper picker. WallpaperState service lives here — only the
# picker uses it. Sets $wallpaperManager for keybinds.nix.

{
  imports = [
    ../../quickshell/core.nix
    ./picker.nix
  ];

  wayland.windowManager.hyprland.settings."$wallpaperManager" =
    "qs ipc call wallpaperPicker toggle";
}

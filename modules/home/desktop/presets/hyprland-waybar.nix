{ ... }:

# Hyprland + Waybar desktop (legacy / fallback).
# Swap ../bar/waybar for ../bar/quickshell to upgrade.

{
  imports = [
    ../wm/hyprland
    ../bar/waybar
    ../tray-apps
    ../clipboard/wl-clipboard.nix
    ../terminal/ghostty.nix
    ../theming/gtk
  ];
}

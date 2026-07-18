{ ... }:

# Full Hyprland + Quickshell desktop.
# Swap any line for an alternative provider (e.g. ../bar/waybar) independently.

{
  imports = [
    ../wm/hyprland
    ../bar/quickshell
    ../launcher/quickshell
    ../notifications/quickshell
    ../osd/quickshell
    ../wallpaper/quickshell
    ../tray-apps
    ../clipboard/wl-clipboard.nix
    ../terminal/ghostty.nix
    ../theming/gtk
  ];
}

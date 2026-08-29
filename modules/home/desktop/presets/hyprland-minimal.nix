{ ... }:

# minimal preset — Hyprland + Waybar (legacy / fallback stack of older apps).
# Swap ../bar/waybar-minimal for ../bar/quickshell-simple to upgrade
# to the simple preset.

{
  imports = [
    ../wm/hyprland
    ../bar/waybar-minimal
    ../tray-apps
    ../clipboard/wl-clipboard.nix
    ../terminal/ghostty.nix
    ../theming/gtk
    ../cursor/adwaita.nix
  ];
}

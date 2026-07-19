{ ... }:

# minimal preset — Hyprland + Waybar (legacy / fallback stack of older apps).
# Swap ../bar/waybar-minimal for ../bar/quickshell-minimal-qs to upgrade
# to the minimal-qs preset.

{
  imports = [
    ../wm/hyprland
    ../bar/waybar-minimal
    ../tray-apps
    ../clipboard/wl-clipboard.nix
    ../terminal/ghostty.nix
    ../theming/gtk
  ];
}

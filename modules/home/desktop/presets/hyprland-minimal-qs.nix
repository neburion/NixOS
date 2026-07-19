{ ... }:

# minimal-qs preset — Hyprland + a plain Quickshell UI (bar, launcher,
# notifications, OSD, wallpaper). Swap any line for an alternative provider
# (e.g. ../bar/waybar-minimal) independently.

{
  imports = [
    ../wm/hyprland
    ../bar/quickshell-minimal-qs
    ../launcher/quickshell-minimal-qs
    ../notifications/quickshell-minimal-qs
    ../osd/quickshell-minimal-qs
    ../wallpaper/quickshell-minimal-qs
    ../tray-apps
    ../clipboard/wl-clipboard.nix
    ../terminal/ghostty.nix
    ../theming/gtk
  ];
}

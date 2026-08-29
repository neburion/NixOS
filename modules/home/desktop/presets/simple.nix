{ ... }:

# simple preset — Hyprland + a plain Quickshell UI (bar, launcher,
# notifications, OSD, wallpaper). Swap any line for an alternative provider
# (e.g. ../bar/waybar-minimal) independently.

{
  imports = [
    ../wm/hyprland
    ../bar/quickshell-simple
    ../launcher/quickshell-simple
    ../notifications/quickshell-simple
    ../osd/quickshell-simple
    ../wallpaper/quickshell-simple
    ../tray-apps
    ../clipboard/wl-clipboard.nix
    ../terminal/ghostty.nix
    ../theming/gtk
    ../cursor/adwaita.nix
    ../theming/spotify.nix
  ];
}

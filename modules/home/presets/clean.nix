{ ... }:

# The clean desktop, whole. Same shape as glass, plus themes/ — this is the
# preset that switches palettes, and the only place `theme-set` exists.

{
  imports = [
    ../desktop/clean/wm
    ../desktop/clean/bar
    ../desktop/clean/launcher
    ../desktop/clean/notifications
    ../desktop/clean/osd
    ../desktop/clean/wallpaper
    ../desktop/clean/terminal.nix
    ../desktop/clean/cursor.nix
    ../desktop/clean/themes

    ../desktop/clean/components/celluloid.nix
    ../desktop/clean/components/libnotify.nix
    ../desktop/clean/components/loupe.nix
    ../desktop/clean/components/nautilus.nix
    ../desktop/clean/components/pavucontrol.nix
    ../desktop/clean/components/wl-clipboard.nix
    ../desktop/clean/components/zathura.nix
    ../desktop/clean/components/wayvnc

    ../desktop/clean/fonts/share-tech-mono.nix
    ../desktop/clean/fonts/fira-mono.nix

    ../desktop/clean/theming/gtk
    ../desktop/clean/theming/spotify.nix
  ];
}

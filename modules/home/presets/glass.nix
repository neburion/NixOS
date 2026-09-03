{ ... }:

# The glass desktop, whole.
#
# desktop/glass/ is a folder, not a module: the bar, launcher, OSD and the rest
# each stand alone, so one can be swapped without touching the others. This
# file is for when you want the lot, which is every time you actually log in.
#
# Everything the desktop needs to be a desktop is in here, including the parts
# Hyprland does not ship — file manager, image viewer, video player, PDF
# reader, clipboard, notification daemon. Delete this preset and its directory
# and none of them are left behind.

{
  imports = [
    # the shell
    ../desktop/glass/wm
    ../desktop/glass/bar
    ../desktop/glass/launcher
    ../desktop/glass/notifications
    ../desktop/glass/osd
    ../desktop/glass/wallpaper
    ../desktop/glass/terminal.nix
    ../desktop/glass/cursor.nix

    # what Hyprland leaves out
    ../desktop/glass/components/celluloid.nix
    ../desktop/glass/components/libnotify.nix
    ../desktop/glass/components/loupe.nix
    ../desktop/glass/components/nautilus.nix
    ../desktop/glass/components/pavucontrol.nix
    ../desktop/glass/components/wl-clipboard.nix
    ../desktop/glass/components/zathura.nix
    ../desktop/glass/components/wayvnc

    # faces this rice is drawn in
    ../desktop/glass/fonts/inter.nix
    ../desktop/glass/fonts/geist.nix
    ../desktop/glass/fonts/material-symbols.nix
    ../desktop/glass/fonts/fira-mono.nix

    # colours for programs the desktop does not own
    ../desktop/glass/theming/gtk
    ../desktop/glass/theming/spotify.nix
    ../desktop/glass/theming/vesktop.nix
  ];
}

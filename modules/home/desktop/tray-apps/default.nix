{ pkgs, ... }:

# Packages that run as system-tray applets alongside quickshell, plus
# libnotify for notify-send (works with quickshell's notification server).

{
  home.packages = with pkgs; [
    libnotify
  ];
}

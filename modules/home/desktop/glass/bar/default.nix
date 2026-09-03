{ ... }:

# Glass status bar. One inset translucent panel per screen, three segments.
# Sets $statusBar so auto-exec.nix starts quickshell.

{
  imports = [
    ../shell
    ./popup-state.nix
    ./popup-widgets.nix
    ./battery.nix
    ./bluetooth.nix
    ./clock.nix
    ./hardware.nix
    ./power-toggle.nix
    ./monitor-toggle.nix
    ./tray.nix
    ./wifi.nix
    ./workspaces.nix
    ./bar.nix
    ./scripts
  ];

  wayland.windowManager.hyprland.settings."$statusBar" = "systemctl --user restart quickshell.service";
}

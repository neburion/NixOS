{ ... }:

# Quickshell status bar. Imports core + all bar components (each self-contained
# with its own service). Sets $statusBar so auto-exec.nix starts quickshell.

{
  imports = [
    ../../quickshell-shared/core.nix
    ./capsule.nix
    ./popup-state.nix
    ./battery.nix
    ./bluetooth.nix
    ./clock.nix
    ./hardware.nix
    ./power-toggle.nix
    ./tray.nix
    ./wifi.nix
    ./workspaces.nix
    ./window-title.nix
    ./ticker.nix
    ./bar.nix
    ./scripts
  ];

  wayland.windowManager.hyprland.settings."$statusBar" = "systemctl --user restart quickshell.service";
}

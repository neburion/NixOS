{ ... }:
{
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      "$statusBar"
      "$notificationDaemon"
      "$wallpaperEngine"
      "$wallpaperManager --restore"
      "$networkApplet"
      "$bluetoothApplet"
      "hypr-session-restore"
    ];
  };
}

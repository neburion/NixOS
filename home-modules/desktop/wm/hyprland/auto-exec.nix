{ ... }:
{
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      "$statusBar"
      "$notificationDaemon"
      "$wallpaperEngine"
      "$wallpaperManager --restore"
      "$nautilus-fix"
      "$networkApplet"
      "$bluetoothApplet"
    ];
  };
}

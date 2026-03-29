{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    "$builtInMonitor" = "eDP-1";
    "$externalMonitor" = "HDMI-A-1";

    monitor = [
      "$builtInMonitor, 1920x1080@120, 0x0, 1"
      "$externalMonitor, 1920x1080@144, 1920x0, 1"
    ];
  };
}

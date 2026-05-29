{ hostConfig, lib, ... }:

let
  monitors = hostConfig.displays.monitors;

  mkMonitorLine = m: "${m.name}, ${m.mode}, ${m.position}, ${m.scale}";
in
{
  wayland.windowManager.hyprland.settings = {
    "$builtInMonitor"  = monitors.builtin.name;
    "$externalMonitor" = monitors.external.name or monitors.builtin.name;

    monitor = lib.mapAttrsToList (_: mkMonitorLine) monitors;
  };
}

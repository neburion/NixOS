{ hostConfig, lib, ... }:

let
  monitors = hostConfig.displays.monitors;

  mkMonitorLine = m:
    let
      base = "${m.name}, ${m.mode}, ${m.position}, ${m.scale}";
    in
    if m ? transform then "${base}, transform, ${toString m.transform}" else base;
in
{
  wayland.windowManager.hyprland.settings = {
    "$builtInMonitor"  = monitors.builtin.name;
    "$externalMonitor" = monitors.external.name or monitors.builtin.name;

    monitor = lib.mapAttrsToList (_: mkMonitorLine) monitors;
  };
}

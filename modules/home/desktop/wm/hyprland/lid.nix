{ hostConfig, ... }:

let
  b = hostConfig.displays.monitors.builtin;
  enableLine  = "${b.name},${b.mode},${b.position},${b.scale}";
  disableLine = "${b.name},disable";
in
{
  wayland.windowManager.hyprland.settings.bindl = [
    ", switch:on:Lid Switch,  exec, hyprctl keyword monitor \"${disableLine}\""
    ", switch:off:Lid Switch, exec, hyprctl keyword monitor \"${enableLine}\""
  ];
}

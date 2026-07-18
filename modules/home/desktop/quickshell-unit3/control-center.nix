{ pkgs, ... }:

# NieR:Automata radial ControlCenter — Wi-Fi / Bluetooth / Audio /
# Quickshare / Notifications. Toggled by "qs ipc call ctrl toggle" (own
# IpcHandler inside ControlCenter.qml). The Quickshare panel calls a
# bundled python script; it degrades gracefully if kdeconnect is absent.
# yazi powers the floating file picker used by Send Files. We reuse
# `ctrl toggle` for both $themeSwitcher and $powerMenu because
# ControlCenter subsumes those functions under Unit-3.

{
  xdg.configFile."quickshell/scripts/qshare.py".source = ./scripts/qshare.py;

  home.packages = [ pkgs.yazi ];

  wayland.windowManager.hyprland.settings = {
    "$themeSwitcher" = "qs ipc call ctrl toggle";
    "$powerMenu"     = "qs ipc call ctrl toggle";
  };
}

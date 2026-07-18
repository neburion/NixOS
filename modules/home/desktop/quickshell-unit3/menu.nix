{ ... }:

# Menu (Super-tap app launcher). Toggled by writing to /tmp/qs-menu, which
# shell.qml polls every 200ms. list-apps.sh scans NixOS + flatpak + user
# .desktop directories.

{
  xdg.configFile = {
    # Menu.qml references it as Qt.resolvedUrl("../list-apps.sh") from Modules/,
    # so it must sit at quickshell/list-apps.sh.
    "quickshell/list-apps.sh" = {
      source     = ./scripts/list-apps.sh;
      executable = true;
    };
  };

  wayland.windowManager.hyprland.settings."$appLauncher" =
    "sh -c 'echo t >> /tmp/qs-menu'";
}

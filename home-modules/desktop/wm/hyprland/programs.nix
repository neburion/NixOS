{ ... }:
{
  wayland.windowManager.hyprland.settings = {
    # Utils
    "$statusBar"          = "waybar";
    "$notificationDaemon" = "mako";
    "$wallpaperEngine"    = "sww-daemon";
    "$networkApplet"      = "nm-applet";
    "$bluetoothApplet"    = "blueman-applet";

    # Apps
    "$terminal"           = "ghostty";
    "$appLauncher"        = "wofi --show drun";
    "$themeSwitcher"      = "wofi-theme-switcher";
    "$powerMenu"          = "wofi-power-menu";
    "$fileManager"        = "thunar";
    "$wallpaperManager"   = "waypaper";
    "$audioManager"       = "pavucontrol";
    "$taskManager"        = "$terminal -e btop";
    "$webBrowser"         = "zen";
    "$musicPlayer"        = "spotify";
    "$notesApp"           = "obsidian";
    "$messenger"          = "signal";
    "$discord"            = "vesktop";
  };
}

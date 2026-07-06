{ ... }:
{
  wayland.windowManager.hyprland.settings = {
    # Utils
    "$statusBar"          = "waybar";
    "$notificationDaemon" = "mako";
    "$wallpaperEngine"    = "awww-daemon";
    "$networkApplet"      = "nm-applet";
    "$bluetoothApplet"    = "blueman-applet";

    # Apps
    "$terminal"         = "ghostty";
    "$appLauncher"      = "wofi --show drun";
    "$themeSwitcher"    = "wofi-theme-switcher";
    "$powerMenu"        = "wofi-power-menu";
    "$fileManager"      = "nautilus";
    "$wallpaperManager" = "waypaper";
    "$audioManager"     = "pavucontrol";
    "$taskManager"      = "$terminal -e btop";
    "$webBrowser"       = "zen";
    "$notesApp"         = "obsidian";
    "$messenger"        = "signal";
    "$discord"          = "vesktop";
    "$musicPlayer"      = "spotify";
    "$gameLauncher"     = "heroic";
    "$steamLauncher"    = "steam";
    "$locker"           = "hyprlock";
    "$localSend"        = "localsend_app";
  };
}

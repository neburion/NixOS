{ ... }:

# Stable app/util bindings. Shell-level vars ($statusBar, $appLauncher,
# $themeSwitcher, $powerMenu) are declared by whichever shell module is
# imported (e.g. modules/home/desktop/quickshell-shared/hyprland.nix), not here.

{
  wayland.windowManager.hyprland.settings = {
    # Apps
    "$terminal"     = "ghostty";
    "$fileManager"  = "nautilus";
    "$audioManager" = "pavucontrol";
    "$taskManager"  = "$terminal -e btop";
    "$webBrowser"   = "zen";
    "$notesApp"     = "obsidian";
    "$messenger"    = "signal";
    "$discord"      = "vesktop";
    "$musicPlayer"  = "spotify";
    "$gameLauncher" = "heroic";
    "$steamLauncher"= "steam";
    "$locker"    = "hyprlock";
    "$localSend" = "localsend_app";
  };
}

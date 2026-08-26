{ pkgs, hostConfig, ... }:

# Forked from ../hyprland/auto-exec.nix. The base restores a single wallpaper
# from ~/.local/state/quickshell/wallpaper and applies it to every output at
# once; this preset assigns wallpapers per monitor, so restoring is
# glass-wallpaper-restore replaying ~/.local/state/quickshell/wallpapers.json.

{
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      "$statusBar"
      "bt-agent"
      "awww-daemon"
      "sleep 2; glass-wallpaper-restore"

      # XWayland reports modes from the X11 "primary" monitor only. Without
      # this, Proton/Wine games (Steam, Heroic) only see the internal panel's
      # 1080p modes and miss the external monitor's 1440p. Mark the external
      # as primary so its mode list reaches the games.
      "${pkgs.xrandr}/bin/xrandr --output ${hostConfig.displays.monitors.external.name} --primary"
    ];
  };
}

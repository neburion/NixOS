{ pkgs, hostConfig, ... }:
{
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      "$statusBar"
      "bt-agent"
      "awww-daemon"
      "sleep 2; f=\"$HOME/.local/state/quickshell/wallpaper\"; [ -f \"$f\" ] && awww img \"$(cat \"$f\")\" --transition-type none || true"

      # XWayland reports modes from the X11 "primary" monitor only. Without
      # this, Proton/Wine games (Steam, Heroic) only see the internal panel's
      # 1080p modes and miss the external monitor's 1440p. Mark the external
      # as primary so its mode list reaches the games.
      "${pkgs.xrandr}/bin/xrandr --output ${hostConfig.displays.monitors.external.name} --primary"
    ];
  };
}

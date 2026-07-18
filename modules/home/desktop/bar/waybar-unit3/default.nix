{ ... }:

# Unit-3 Waybar — sepia NieR bar (fixed palette, no theming).
# Systemd-managed (like quickshell) so X-Restart-Triggers live-reloads it on rebuild.

{
  imports = [
    ./config.nix
    ./style.nix
    ./scripts/pomodoro.nix
  ];

  programs.waybar = {
    enable = true;
    systemd.enable = true;
  };

  wayland.windowManager.hyprland.settings."$statusBar" = "systemctl --user restart waybar.service";
}

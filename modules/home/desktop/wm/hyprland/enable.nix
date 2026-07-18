{ lib, ... }:

{
  wayland.windowManager.hyprland = {
    enable         = true;
    configType     = "hyprlang";
    systemd.enable = false;  # uwsm manages the session; home-manager's dbus exec-once conflicts
  };

  # Reload hyprland config (keybinds, looks, window-rules) after every rebuild.
  # Best-effort: silently skips if hyprland isn't running (e.g. TTY rebuild).
  home.activation.reloadHyprland = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    hyprctl reload 2>/dev/null || true
  '';
}

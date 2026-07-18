{ ... }:

# Unit-3's signature bind — SUPER+Tab opens the ControlCenter radial menu.
# All other keybinds come from ../hyprland/keybinds.nix unchanged.

{
  wayland.windowManager.hyprland.settings.bind = [
    "SUPER, Tab, exec, qs ipc call ctrl toggle"
  ];
}

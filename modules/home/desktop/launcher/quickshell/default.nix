{ ... }:

# Quickshell app launcher, theme switcher, and power menu.
# Sets the three variables consumed by hyprland/keybinds.nix.

{
  imports = [
    ../../quickshell/core.nix
    ./app-launcher.nix
    ./theme-switcher.nix
    ./power-menu.nix
  ];

  wayland.windowManager.hyprland.settings = {
    "$appLauncher"   = "qs ipc call launcher toggle";
    "$themeSwitcher" = "qs ipc call themeSwitcher toggle";
    "$powerMenu"     = "qs ipc call powerMenu toggle";
  };
}

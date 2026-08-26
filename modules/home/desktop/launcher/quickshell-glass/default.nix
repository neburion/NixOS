{ ... }:

# Glass app launcher and power menu.
#
# No theme-switcher.nix, so $themeSwitcher is never defined and the
# $mod SHIFT + Space bind is dropped in wm/hyprland-glass/keybinds.nix.

{
  imports = [
    ../../quickshell-glass-shared
    ./app-launcher.nix
    ./power-menu.nix
  ];

  wayland.windowManager.hyprland.settings = {
    "$appLauncher" = "qs ipc call launcher toggle";
    "$powerMenu"   = "qs ipc call powerMenu toggle";
  };
}

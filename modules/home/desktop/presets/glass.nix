{ pkgs, ... }:

# glass preset — Hyprland + a translucent Quickshell UI, one fixed palette,
# and a launcher that stays empty until you type.
#
# What separates it from `clean` and `simple`, beyond styling:
#
#   - No themes. ../theming/gtk/theme-sync.nix, ../wm/hyprland/themes.nix and
#     the theme switcher are all left unimported, so nothing regenerates on a
#     theme change because there is no theme to change. `theme-set` still
#     exists (base.nix imports the switcher module for the other presets); it
#     simply has fewer hooks registered.
#   - The bar is translucent, which only works because
#     ../wm/hyprland-glass/layer-rules.nix blurs the layer namespaces the
#     quickshell surfaces declare. Swapping the WM module out leaves the shell
#     looking flat rather than broken, which is the failure mode to expect.
#   - Wallpapers are per monitor. ../wallpaper/quickshell-glass writes
#     ~/.local/state/quickshell/wallpapers.json keyed by output, and each bar
#     takes its accent from its own screen's wallpaper.

{
  imports = [
    ../wm/hyprland-glass
    ../bar/quickshell-glass
    ../launcher/quickshell-glass
    ../notifications/quickshell-glass
    ../osd/quickshell-glass
    ../wallpaper/quickshell-glass
    ../tray-apps
    ../clipboard/wl-clipboard.nix
    ../terminal/ghostty-glass.nix
    ../theming/gtk-glass
  ];

  home.packages = with pkgs; [
    inter             # UI. Ships "Inter" and "Inter Display" from one ttc.
    geist-font        # Geist Mono for digits, labels and the terminal.
    material-symbols  # Rounded, variable — the FILL axis carries active state.
  ];

  fonts.fontconfig.enable = true;
}

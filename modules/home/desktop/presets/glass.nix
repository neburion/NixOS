{ pkgs, lib, config, ... }:

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
    ../cursor/whitesur.nix
    ../theming/spotify-glass.nix
  ];

  home.packages = with pkgs; [
    inter             # UI. Ships "Inter" and "Inter Display" from one ttc.
    geist-font        # Geist Mono for digits, labels and the terminal.
    material-symbols  # Rounded, variable — the FILL axis carries active state.
  ];

  fonts.fontconfig.enable = true;

  # Pin the tools that are still theme-driven.
  #
  # neovim, fish and superfile are CLI modules imported straight from home.nix,
  # not by any preset — a headless host gets them too — so they keep following
  # ~/.local/state/quickshell/active-theme. Under glass nothing ever calls
  # theme-set, so they sit on whatever palette was last chosen and drift out of
  # step with the desktop; that is why neovim stayed gruvbox long after the rest
  # of the preset had changed.
  #
  # Spotify used to be named here too, and it never belonged: its themeHook
  # shelled out to a `spicetify` binary that is not installed, so every switch
  # was a no-op and it sat on the `dark` palette regardless. Its colours are
  # ../theming/spotify-glass.nix now, imported above like any other surface the
  # preset owns.
  #
  # `themes/glass.nix` gives them a palette that matches, and this runs the
  # hooks once to adopt it. Guarded on the current value, so it does not fight
  # a deliberate `theme-set <other>` on every activation — switch away and it
  # stays switched.
  home.activation.pinGlassTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    STATE="$HOME/.local/state/quickshell/active-theme"
    if [ "$(cat "$STATE" 2>/dev/null)" != "glass" ]; then
      "${config.home.profileDirectory}/bin/theme-set" glass || true
    fi
  '';
}

{ pkgs, ... }:

# Full Hyprland + Waybar + Quickshell-widgets desktop, NieR:Automata rice
# (port of samyns/Unit-3). Swap any line for an alternative provider
# independently — see ARCHITECTURE.md "Shell auto-wiring".

{
  imports = [
    ../wm/hyprland-unit3
    ../bar/waybar-unit3
    ../quickshell-unit3
    ../tray-apps
    ../clipboard/wl-clipboard.nix
    ../terminal/kitty-unit3.nix
    ../theming/gtk
  ];

  # Fonts the whole Unit-3 aesthetic depends on. Share Tech Mono for every
  # label (waybar, kitty, quickshell, hyprlock); Noto Sans JP for the katakana
  # subtitle in hyprlock and the ticker chars in waybar/ControlCenter.
  home.packages = with pkgs; [
    (google-fonts.override { fonts = [ "ShareTechMono" ]; })
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  fonts.fontconfig.enable = true;
}

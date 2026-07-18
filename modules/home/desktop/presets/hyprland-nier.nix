{ pkgs, ... }:

# NieR preset — quickshell base with unit3-inspired sepia aesthetics.
# Each component lives in its own *-nier directory for independent divergence.

{
  imports = [
    ../wm/hyprland-nier
    ../bar/quickshell-nier
    ../launcher/quickshell-nier
    ../notifications/quickshell-nier
    ../osd/quickshell-nier
    ../wallpaper/quickshell-nier
    ../tray-apps
    ../clipboard/wl-clipboard.nix
    ../terminal/kitty-unit3.nix
    ../theming/gtk
  ];

  home.packages = with pkgs; [
    (google-fonts.override { fonts = [ "ShareTechMono" ]; })
    noto-fonts-cjk-sans
  ];

  fonts.fontconfig.enable = true;
}

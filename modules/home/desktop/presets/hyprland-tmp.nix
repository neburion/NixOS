{ pkgs, ... }:

# tmp preset — quickshell base with sepia NieR:Automata aesthetics.
# Each component lives in its own *-tmp directory for independent divergence.

{
  imports = [
    ../wm/hyprland-tmp
    ../bar/quickshell-tmp
    ../launcher/quickshell-tmp
    ../notifications/quickshell-tmp
    ../osd/quickshell-tmp
    ../wallpaper/quickshell-tmp
    ../tray-apps
    ../clipboard/wl-clipboard.nix
    ../terminal/ghostty-tmp.nix
    ../theming/gtk
  ];

  home.packages = with pkgs; [
    (google-fonts.override { fonts = [ "ShareTechMono" ]; })
    noto-fonts-cjk-sans
  ];

  fonts.fontconfig.enable = true;
}

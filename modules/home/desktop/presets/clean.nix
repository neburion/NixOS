{ pkgs, ... }:

# clean preset — quickshell base with sepia terminal aesthetics.
# Each component lives in its own *-clean directory for independent divergence.

{
  imports = [
    ../wm/hyprland-clean
    ../bar/quickshell-clean
    ../launcher/quickshell-clean
    ../notifications/quickshell-clean
    ../osd/quickshell-clean
    ../wallpaper/quickshell-clean
    ../tray-apps
    ../clipboard/wl-clipboard.nix
    ../terminal/ghostty-clean.nix
    ../theming/gtk
    ../theming/spotify.nix
  ];

  home.packages = with pkgs; [
    (google-fonts.override { fonts = [ "ShareTechMono" ]; })
  ];

  fonts.fontconfig.enable = true;
}

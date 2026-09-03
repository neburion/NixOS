{ pkgs, ... }:

# clean preset — quickshell base with sepia terminal aesthetics.
# Each component lives in its own *-clean directory for independent divergence.

{
  imports = [
    ./wm
    ./bar
    ./launcher
    ./notifications
    ./osd
    ./wallpaper
    ./terminal.nix
    ./cursor.nix
    ./theming/gtk
    ./theming/spotify.nix
    ./themes
  ];

  home.packages = with pkgs; [
    (google-fonts.override { fonts = [ "ShareTechMono" ]; })
  ];

  fonts.fontconfig.enable = true;
}

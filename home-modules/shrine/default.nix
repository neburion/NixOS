{ pkgs, ... }:

{
  imports = [
    ./hyprland.nix
    ./shrine-shell.nix
  ];

  home.packages = with pkgs; [
    ghostty
  ];

  programs.ghostty = {
    enable = true;
    settings = {
      background             = "0d0d0d";
      foreground             = "d4af37";
      selection-background   = "d4af37";
      selection-foreground   = "0d0d0d";
      cursor-color           = "d4af37";
      font-size              = 16;
      window-decoration      = false;
      scrollbar-style        = "overlay";
    };
  };
}

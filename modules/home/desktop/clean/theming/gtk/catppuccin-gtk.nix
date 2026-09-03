{ pkgs, ... }:

let
  catppuccin-gtk = pkgs.catppuccin-gtk.override {
    accents = [ "blue" ];
    size    = "standard";
    variant = "mocha";
  };
in
{
  home.packages = [ catppuccin-gtk ];
}

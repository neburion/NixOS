{ pkgs, ... }:

let
  wofi-power-menu     = import ./wofi-power-menu.nix     { inherit pkgs; };
  wofi-theme-switcher = import ./wofi-theme-switcher.nix { inherit pkgs; };
in
{
  home.packages = [
    wofi-power-menu
    wofi-theme-switcher
  ];
}

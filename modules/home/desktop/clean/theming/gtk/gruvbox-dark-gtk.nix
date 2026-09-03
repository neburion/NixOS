{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gruvbox-dark-gtk
  ];
}

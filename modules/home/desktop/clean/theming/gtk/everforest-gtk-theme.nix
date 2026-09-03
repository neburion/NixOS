{ pkgs, ... }:

{
  home.packages = with pkgs; [
    everforest-gtk-theme
  ];
}

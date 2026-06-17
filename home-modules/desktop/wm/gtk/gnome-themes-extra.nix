{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gnome-themes-extra
  ];
}

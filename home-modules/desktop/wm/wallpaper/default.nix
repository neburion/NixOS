{ pkgs, ... }:

{
  home.packages = with pkgs; [
    swww     # wallpaper engine
    waypaper # wallpaper manager
  ];
}

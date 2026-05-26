{ pkgs, ... }:

{
  imports = [
    ./waypaper.nix
    ./sync.nix
  ];

  home.packages = with pkgs; [
    swww     # wallpaper engine
    waypaper # wallpaper manager GUI
  ];
}

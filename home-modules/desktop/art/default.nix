{ pkgs, ... }:

{
  imports = [ 
  ];

  home.packages = with pkgs; [
    aseprite
    blender
  ];
}

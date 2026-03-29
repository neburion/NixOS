{ pkgs, ... }:

{
  home.packages = with pkgs; [
    heroic
    atlauncher
  ];
}

{ pkgs, ... }:

{
  home.packages = with pkgs; [
    glib
  ];
}

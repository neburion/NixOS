{ pkgs, ... }:

{
  imports = [ 
    ./appimage.nix
    ./flatpak.nix
  ];
}

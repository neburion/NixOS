{ pkgs, ... }:

{
  imports = [
    ./appimage.nix
    ./compression.nix
    ./fish.nix
    ./flatpak.nix
    ./git.nix
    ./neovim
    ./superfile.nix
  ];

  home.packages = with pkgs; [
    btop
    fastfetch
    tree
  ];
}

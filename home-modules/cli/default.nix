{ pkgs, ... }:

{
  imports = [ 
    ./bash.nix
    ./fish.nix
    ./superfile.nix
    ./git.nix
    ./neovim
  ];
  home.packages = with pkgs; [
    p7zip
    unrar
    unzip
    btop
    fastfetch
    tree
  ];
}

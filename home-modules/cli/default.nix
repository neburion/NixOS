{ pkgs, ... }:

{
  imports = [ 
    ./bash.nix
    ./fish.nix
    ./superfile.nix
    ./neovim
    ./git.nix
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

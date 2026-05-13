{ pkgs, ... }:

{
  imports = [ 
    ./bash.nix
    ./superfile.nix
    ./git.nix
    ./neovim
    ./package
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

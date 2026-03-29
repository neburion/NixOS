{ pkgs, ... }:

{
  imports = [ 
    ./bash.nix
    ./superfile.nix
    ./neovim.nix
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

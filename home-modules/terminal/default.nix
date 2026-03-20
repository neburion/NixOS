{ pkgs, ... }:
{
  imports = [ 
    ./bash.nix
    ./ghostty.nix
    ./superfile.nix
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

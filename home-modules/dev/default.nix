{ pkgs, ... }:
{
  imports = [ 
    ./scripts
    ./git.nix
    ./neovim.nix
  ];

  home.packages = with pkgs; [
    # Compilers
    gcc

    # Build Tools
    bear
    gnumake
    cmake

    # Debbegers
    gdb
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}

{ pkgs, ... }:

{
  imports = [ 
    ./scripts
  ];

  home.packages = with pkgs; [
    # Compilers & Interpretes
    gcc
    python3

    # Build Tools
    gnumake
    cmake
    
    # Debbegers
    gdb
    
    # Game Engine
    godot
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}

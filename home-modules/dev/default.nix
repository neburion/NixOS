{ pkgs, ... }:

{
  imports = [
    ./scripts
    ./ai
  ];

  home.packages = with pkgs; [
    # Compilers & Interpreters
    gcc
    python3

    # Build Tools
    gnumake
    cmake

    # Debuggers
    gdb
    
    # Game Engine
    godot
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}

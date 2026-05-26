{ pkgs, ... }:

{
  imports = [ 
  ];
  home.packages = with pkgs; [
    claude-code
    opencode
  ];
}

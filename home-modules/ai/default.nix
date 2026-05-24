{ pkgs, ... }:

{
  imports = [ 
  ];
  home.packages = with pkgs; [
    opencode
  ];
}

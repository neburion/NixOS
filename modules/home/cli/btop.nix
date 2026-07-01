{ pkgs, ... }:

{
  home.packages = with pkgs; [
    btop
    claude-code
  ];
}

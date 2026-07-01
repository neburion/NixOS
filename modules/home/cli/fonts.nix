{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nerd-fonts.fira-mono
  ];

  fonts.fontconfig.enable = true;
}

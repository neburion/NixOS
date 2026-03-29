{ pkgs, ... }:

{
  imports = [
    ../home-modules/cli
  ];

  home.packages = with pkgs; [firefox];

  home.stateVersion = "25.11";
}

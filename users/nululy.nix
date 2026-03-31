{ pkgs, ... }:

{
  imports = [
    ../home-modules/desktop
    ../home-modules/cli
  ];

  home.packages = with pkgs; [firefox];

  home.stateVersion = "25.11";
  xdg.configFile."user-dirs.dirs".force = true;
}

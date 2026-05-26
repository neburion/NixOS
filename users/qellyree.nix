{ ... }:

{
  imports = [
    ../home-modules/desktop
    ../home-modules/desktop/gaming
    ../home-modules/cli
  ];

  home.stateVersion = "25.11";
  xdg.configFile."user-dirs.dirs".force = true;
}

{ zen-browser, nvf, ... }:

{
  imports = [
    ../home-modules/desktop
    ../home-modules/cli
    ../home-modules/dev
  ];

  home.stateVersion = "25.11";
  xdg.configFile."user-dirs.dirs".force = true;
}

{ pkgs, zen-browser, ... }:

{
  imports = [
    ../home-modules/desktop
    ../home-modules/cli
    ../home-modules/dev
  ];

  home.packages = with pkgs; [
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    sqlite
  ];

  home.stateVersion = "25.11";
  xdg.configFile."user-dirs.dirs".force = true;
}

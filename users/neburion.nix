{ zen-browser, claude-desktop, pkgs, ... }:

{
  imports = [
    ../home-modules/desktop
    ../home-modules/cli
    ../home-modules/dev
  ];

  home.packages = [
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop-with-fhs
    pkgs.sqlite
  ];
  programs.nvf.enable = true;

  home.stateVersion = "25.11";
  xdg.configFile."user-dirs.dirs".force = true;
}

{ zen-browser, pkgs, ... }:

{
  imports = [
    ../home-modules/desktop
    ../home-modules/desktop/wm/lock.nix
    ../home-modules/cli
    ../home-modules/dev
  ];

  home.packages = [
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.sqlite
  ];
  programs.nvf.enable = true;

  home.stateVersion = "25.11";
  xdg.configFile."user-dirs.dirs".force = true;
}

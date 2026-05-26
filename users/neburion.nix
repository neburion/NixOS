{ zen-browser, pkgs, ... }:

{
  imports = [
    ../home-modules/desktop
    ../home-modules/cli
    ../home-modules/dev
    ../home-modules/cli/backup.nix
  ];

  home.packages = [ zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  programs.nvf.enable = true;

  home.stateVersion = "25.11";
  xdg.configFile."user-dirs.dirs".force = true;
}

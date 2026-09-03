{ pkgs, zen-browser, ... }:

{
  home.packages = [
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}

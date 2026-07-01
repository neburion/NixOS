{ pkgs, ... }:

{
  home.packages = with pkgs; [
    libreoffice
    hunspell
    hunspellDicts.en-us
    hunspellDicts.fr-moderne
  ];
}

{ pkgs, ... }:

{
  home.packages = with pkgs; [
    libreoffice-qt
    hunspell
    hunspellDicts.en-us
    hunspellDicts.fr-moderne
  ];
}

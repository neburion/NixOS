{ pkgs, ... }:

{
  imports = [
    ./battery.nix
  ];

  home.packages = with pkgs; [
    solaar
  ];
}

{ pkgs, ... }:

{
  home.packages = with pkgs; [
    heroic
    prismlauncher
  ];
}

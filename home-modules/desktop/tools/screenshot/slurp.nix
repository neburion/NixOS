{ pkgs, ... }:

{
  home.packages = with pkgs; [
    slurp
  ];
}

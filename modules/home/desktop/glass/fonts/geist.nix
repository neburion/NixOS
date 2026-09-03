{ pkgs, ... }:

# Geist Mono — digits, labels, and the terminal.

{
  home.packages = [ pkgs.geist-font ];
  fonts.fontconfig.enable = true;
}

{ pkgs, ... }:

# UI face. Ships "Inter" and "Inter Display" from one ttc.

{
  home.packages = [ pkgs.inter ];
  fonts.fontconfig.enable = true;
}

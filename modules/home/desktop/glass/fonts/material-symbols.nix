{ pkgs, ... }:

# Rounded and variable. The FILL axis carries active state, so the bar animates along it instead of swapping glyphs.

{
  home.packages = [ pkgs.material-symbols ];
  fonts.fontconfig.enable = true;
}

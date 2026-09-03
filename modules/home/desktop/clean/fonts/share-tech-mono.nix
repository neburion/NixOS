{ pkgs, ... }:

# The sepia rice terminal face.

{
  home.packages = [ (pkgs.google-fonts.override { fonts = [ "ShareTechMono" ]; }) ];
  fonts.fontconfig.enable = true;
}

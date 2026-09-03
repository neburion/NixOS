{ pkgs, ... }:

# Nerd-patched Fira Mono, for the glyphs prompts and file listings expect.

{
  home.packages = [ pkgs.nerd-fonts.fira-mono ];
  fonts.fontconfig.enable = true;
}

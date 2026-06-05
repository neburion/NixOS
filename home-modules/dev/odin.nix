{ pkgs, ... }:

{
  home.packages = with pkgs; [
    odin
  ];

  programs.nvf.settings.vim.languages.odin.enable = true;
}

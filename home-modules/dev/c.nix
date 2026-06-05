{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gcc
  ];

  programs.nvf.settings.vim.languages.clang.enable = true;
}

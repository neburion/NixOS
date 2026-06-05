{ pkgs, ... }:

{
  home.packages = with pkgs; [
    python3
  ];

  programs.nvf.settings.vim.languages.python.enable = true;
}

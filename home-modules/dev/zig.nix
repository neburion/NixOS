{ pkgs, ... }:

{
  home.packages = with pkgs; [
    zig
  ];

  programs.nvf.settings.vim.languages.zig.enable = true;
}

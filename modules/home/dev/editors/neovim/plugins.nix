{ ... }:

{
  programs.nvf.settings.vim = {
    telescope.enable = true;
    autocomplete.nvim-cmp.enable = true;
    treesitter = {
      enable = true;
      context.enable = true;
    };
  };
}

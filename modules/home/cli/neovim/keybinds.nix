{ ... }:

{
  programs.nvf.settings.vim.maps.normal = {
    "<leader>f" = {
      action = "<cmd>Telescope find_files<CR>";
      desc = "Find files";
    };

    "<leader>e" = {
      action = "<cmd>lua vim.diagnostic.open_float()<CR>";
      desc = "Diagnostic float";
    };

    "<leader>t" = {
      action = "<cmd>lua vim.cmd('new') vim.cmd('terminal') vim.cmd('startinsert')<CR>";
      desc = "Opens the terminal";
    };
  };
}

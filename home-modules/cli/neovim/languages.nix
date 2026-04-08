{ ... }:

{
  programs.nvf.settings.vim.maps.normal = {
    "<leader>ff" = {
      action = "<cmd>Telescope find_files<CR>";
      desc = "Find files";
    };

    "<leader>e" = {
      action = "<cmd>lua vim.diagnostic.open_float()<CR>";
      desc = "Diagnostic float";
    };
  };
}

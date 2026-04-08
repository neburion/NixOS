{ ... }:

{
  programs.nvf = {
    enable = true;
    settings.vim = {
      # Line numbers and tabs
      options = {
        number = true;
        relativenumber = true;
        tabstop = 4;
        shiftwidth = 4;
        expandtab = true;
      };
      luaConfigRC.nix-indentation = ''
        vim.api.nvim_create_autocmd("FileType", {
          pattern = "nix",
          callback = function()
          vim.bo.tabstop = 2
          vim.bo.shiftwidth = 2
          end,
        })
      '';

      # Theme
      theme = {
        enable = true;
        name = "catppuccin";
        style = "mocha";
      };

      # Autocomplete
      autocomplete.nvim-cmp.enable = true;

      # Treesitter
      treesitter = {
        enable = true;
        context.enable = true;
      };

      # Telescope
      telescope.enable = true;

      # LSP
      lsp.enable = true;
      languages = {
        enableTreesitter = true;

        clang.enable  = true; # C/C++
        rust.enable   = true; # Rust
        python.enable = true; # Python
        nix.enable    = true; # Nix
      };

      # Keybinds
      maps.normal = {
        # Telescope
        "<leader>ff" = {
          action = "<cmd>Telescope find_files<CR>";
          desc = "Find files";
        };

        # Shows Diagnostics
        "<leader>e" = {
          action = "<cmd>lua vim.diagnostic.open_float()<CR>";
          desc = "Diagnostic float";
        };
      };
    };
  };
}

{ ... }:

{
  programs.nvf = {
    enable = true;
    settings.vim = {
      # Line numbers
      options = {
        number = true;
        relativenumber = true;
        tabstop = 4;
        shiftwidth = 4;
        expandtab = true;
      };

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

        clang.enable = true;   # C
        rust.enable = true;    # Rust
        python.enable = true;  # Python
        languages.nix = {      # Nix
          enable = true;
          lsp.enable = true;
          lsp.server = "nixd"; # or "nil"
        };
      };

      # Keybinds
      maps.normal = {
        # Telescope
        "<leader>ff" = {
          action = "<cmd>Telescope find_files<CR>";
          desc = "Find files";
        };
        "<leader>fg" = {
          action = "<cmd>Telescope live_grep<CR>";
          desc = "Live grep";
        };
        "<leader>fb" = {
          action = "<cmd>Telescope buffers<CR>";
          desc = "Buffers";
        };

        # LSP diagnostics
        "<leader>dd" = {
          action = "<cmd>Telescope diagnostics<CR>";
          desc = "Show diagnostics";
        };
        "[d" = {
          action = "<cmd>lua vim.diagnostic.goto_prev()<CR>";
          desc = "Previous diagnostic";
        };
        "]d" = {
          action = "<cmd>lua vim.diagnostic.goto_next()<CR>";
          desc = "Next diagnostic";
        };
        "<leader>e" = {
          action = "<cmd>lua vim.diagnostic.open_float()<CR>";
          desc = "Diagnostic float";
        };
      };

    };
  };
}

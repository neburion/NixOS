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

    # Fill a switch with every enumerator it is missing, via clangd's
    # PopulateSwitch tweak.
    #
    # This is the same thing <leader>la offers, minus the picker. The filter
    # narrows the response to that one action and apply = true runs it when
    # exactly one survives, so the common case is a single keystroke.
    #
    # clangd only offers the tweak when the switch condition genuinely has
    # enum type -- an int or uint8_t holding an enumerator is not enough --
    # and when the switch has no default: label, since a default makes it
    # exhaustive as far as clangd is concerned. The cursor has to sit on the
    # switch (...) header line or the closing brace; a blank line inside the
    # body resolves to the enclosing block instead and offers nothing.
    "<leader>po" = {
      action = ''
        function()
          vim.lsp.buf.code_action({
            apply = true,
            filter = function(action)
              return action.title == "Populate switch"
            end,
          })
        end
      '';
      lua = true;
      desc = "Populate switch";
    };
  };
}

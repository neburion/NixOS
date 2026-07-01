{ ... }:

{
  programs.nvf.settings.vim = {
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
  };
}

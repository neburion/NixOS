{ ... }:

{
  programs.nvf.settings.vim.debugger.nvim-dap = {
    enable    = true;
    ui.enable = true;

    # gdb adapter + default C launch configuration.
    # gdb 14+ supports DAP natively via `-i=dap`, so no separate adapter
    # binary is needed. Pairs naturally with GCC-compiled binaries.
    sources.gdb = ''
      dap.adapters.gdb = {
        type = "executable",
        command = "gdb",
        args = { "-i=dap" },
      }

      dap.configurations.c = {
        {
          name = "Launch",
          type = "gdb",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd = "''${workspaceFolder}",
          stopAtBeginningOfMainSubprogram = false,
        },
      }
    '';
  };
}

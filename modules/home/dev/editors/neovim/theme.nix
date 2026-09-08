{ pkgs, ... }:

let
  # Tokyodark, with the ground knocked back out from under it.
  #
  # This module used to take the repo-wide `themes` attrset, write one lua
  # snippet per palette, install four colorscheme plugins, and register a
  # theme-set hook that re-sourced the active snippet over a per-PID IPC
  # socket — all so an editor that runs fine over ssh would follow the
  # desktop's palette. That machinery is also what hid the bug it existed to
  # solve: glass never calls theme-set, so nvim sat on gruvbox for months
  # after the desktop had changed. One scheme, named here, cannot drift.
  #
  # The ground groups are cleared rather than repainted. The terminal runs at
  # background-opacity 0.92 with blur, so any cell nvim paints itself is
  # opaque and the buffer reads as a solid rectangle pasted over a translucent
  # window — visible as a hard edge against the padding. Leaving them unset
  # lets the terminal's own ground show through.
  #
  # Raised surfaces — floats, popup menu, statusline, cursorline, visual —
  # are deliberately left alone, so tokyodark keeps painting them opaque.
  # They are meant to sit above the glass, not be part of it.
  #
  # tokyodark ships its own `transparent_background`, which is not used: it
  # clears more than the ground and takes the raised surfaces with it.
  theme = ''
    require("tokyodark").setup({
      transparent_background = false,
      gamma = 1.00,
    })

    vim.o.background = "dark"
    vim.cmd.colorscheme("tokyodark")

    -- Groups that make up the buffer's ground. Anything not listed keeps the
    -- colorscheme's own background on purpose.
    local ground = {
      "Normal", "NormalNC", "SignColumn", "FoldColumn",
      "MsgArea", "NonText", "LineNr",
    }

    local function unpaint()
      -- `~` past the last line is hidden by matching the scheme's own ground,
      -- which has to be read before that ground is cleared away.
      local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
      local void = normal.bg

      for _, group in ipairs(ground) do
        local spec = vim.api.nvim_get_hl(0, { name = group, link = false })
        spec.bg, spec.ctermbg = nil, nil
        vim.api.nvim_set_hl(0, group, spec)
      end

      vim.api.nvim_set_hl(0, "EndOfBuffer", { fg = void })
    end

    unpaint()

    -- Anything that reloads the colorscheme repaints the ground, so redo it.
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("glass-ground", { clear = true }),
      callback = unpaint,
    })
  '';
in
{
  programs.nvf.settings.vim = {
    startPlugins = [ pkgs.vimPlugins.tokyodark-nvim ];
    theme.enable = false;
    luaConfigPost = theme;
  };
}

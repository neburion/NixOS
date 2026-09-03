{ ... }:

let
  # Its own colours, literal, matching desktop/glass/palette.nix.
  #
  # This module used to take the repo-wide `themes` attrset, write one lua
  # snippet per palette, install four colorscheme plugins, and register a
  # theme-set hook that re-sourced the active snippet over a per-PID IPC
  # socket — all so an editor that runs fine over ssh would follow the
  # desktop's palette.
  #
  # That machinery is also what hid the bug it existed to solve. glass never
  # calls theme-set, so nvim kept whatever was last selected and sat on gruvbox
  # for months after the desktop had changed. One palette, written down here,
  # cannot drift from itself.
  t = {
    bg            = "#101113";
    surface       = "#191B1E";
    selection     = "#26282C";
    fg            = "#E8EAEC";
    fishSecondary = "#6E737A";
  };

  # No plugin: the built-in scheme with its ground repainted. nvim's default
  # dark leans blue, which is the one thing this palette is trying not to be.
  #
  # The ground groups are cleared to NONE rather than set to `t.bg`. The
  # terminal runs at background-opacity 0.92 with blur, so any cell nvim paints
  # itself is opaque and the buffer reads as a solid rectangle pasted over a
  # translucent window — visible as a hard edge against the padding. Leaving
  # them unset lets the terminal's own ground show through, which is the same
  # colour anyway, only translucent.
  #
  # Raised surfaces (floats, popup menu, statusline, cursorline, visual) keep
  # their opaque surface/selection fill on purpose: they are meant to sit above
  # the glass, not be part of it.
  theme = ''
    vim.o.background = "dark"
    vim.cmd.colorscheme("default")

    local surface, selection, fg =
      "${t.surface}", "${t.selection}", "${t.fg}"
    local NONE = "NONE"

    local function hl(group, spec) vim.api.nvim_set_hl(0, group, spec) end

    hl("Normal",       { bg = NONE,      fg = fg })
    hl("NormalNC",     { bg = NONE,      fg = fg })
    hl("NormalFloat",  { bg = surface,   fg = fg })
    hl("FloatBorder",  { bg = surface,   fg = "${t.fishSecondary}" })
    hl("SignColumn",   { bg = NONE })
    hl("FoldColumn",   { bg = NONE })
    hl("EndOfBuffer",  { bg = NONE,      fg = "${t.bg}" })
    hl("MsgArea",      { bg = NONE,      fg = fg })
    hl("NonText",      { bg = NONE })
    hl("CursorLine",   { bg = surface })
    hl("CursorLineNr", { bg = surface,   fg = fg })
    hl("LineNr",       { bg = NONE,      fg = "${t.fishSecondary}" })
    hl("Visual",       { bg = selection })
    hl("StatusLine",   { bg = surface,   fg = fg })
    hl("StatusLineNC", { bg = surface,   fg = "${t.fishSecondary}" })
    hl("WinSeparator", { bg = NONE,      fg = selection })
    hl("Pmenu",        { bg = surface,   fg = fg })
    hl("PmenuSel",     { bg = selection, fg = fg })
  '';
in
{
  # No startPlugins: catppuccin, gruvbox, nord and everforest were installed
  # only so a switcher could pick between them at runtime. Nothing switches now.
  programs.nvf.settings.vim = {
    theme.enable = false;
    luaConfigPost = theme;
  };
}

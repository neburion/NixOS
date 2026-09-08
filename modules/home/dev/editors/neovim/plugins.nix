{ ... }:

{
  programs.nvf.settings.vim = {
    telescope.enable = true;
    autocomplete.nvim-cmp.enable = true;
    treesitter = {
      enable = true;
      context.enable = true;
    };

    # Indent guides, drawn as hairlines rather than full-cell strokes.
    #
    # The character matters more than it looks. U+2502 (│), the obvious pick
    # and indent-blankline's default, is a box-drawing glyph that strokes down
    # the middle of the cell and reads as clutter on every indented line.
    # U+258F (▏, left one-eighth block) sits at the cell's left edge instead,
    # which is the thin rule VS Code and the JetBrains editors draw.
    #
    # It stays continuous down the block: ghostty renders box and block
    # characters from its own internal sprite face, not from the font, so they
    # join across cell boundaries. Geist Mono would very nearly manage it
    # unaided anyway -- the glyph covers all but one pixel row of a 38px cell.
    #
    # scope is what actually answers "where does this end": it takes the block
    # under the cursor from the same treesitter parse that colours the syntax,
    # and underlines its first and last line. treesitter.context above pins the
    # opening line to the top of the window; this marks the closing one.
    visuals.indent-blankline = {
      enable = true;
      setupOpts = {
        indent.char = "▏";
        scope = {
          enabled    = true;
          char       = "▏";
          show_start = true;
          show_end   = true;
        };
      };
    };
  };
}

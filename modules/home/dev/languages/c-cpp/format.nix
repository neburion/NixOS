{ lib, ... }:

{
  # Column-aligned declarations, assignments, macros and bitfields on write.
  #
  # There is no alignment-only mechanism. Neovim cannot do this as you type,
  # and clang-format's Align* options only exist inside a full reformat, so
  # every save rewrites the whole buffer -- brace placement, spacing, wrapping
  # at 80 columns -- not just the columns. That is the price of the alignment.
  #
  # nvf already owns the plumbing: languages.clang.format wires conform-nvim to
  # clang-format and sets formatters_by_ft for c and cpp. It was off only
  # because nothing here sets languages.enableFormat.
  programs.nvf.settings.vim.languages.clang.format.enable = true;

  # The style arrives on the command line rather than as a config file.
  #
  # clang-format resolves -style=file by walking up from the source file and
  # stops at the filesystem root; it does not consult $HOME/.clang-format, so
  # there is no user-level default to drop a file into. -fallback-style refuses
  # inline YAML and takes only the name of a builtin. That leaves -style={...},
  # which overrides file lookup entirely -- hence the vim.fs.find guard, which
  # yields to a project's own .clang-format when one exists upward of the file.
  #
  # IndentWidth and UseTab are read off the buffer instead of being written
  # down, so the formatter agrees with the tabstop/expandtab settings in
  # editors/neovim/options.nix rather than silently reindenting to LLVM's 2.
  #
  # prepend_args, not args: conform's builtin already passes
  # -assume-filename $FILENAME, which is what tells clang-format it is looking
  # at C when the text arrives on stdin.
  programs.nvf.settings.vim.formatter.conform-nvim.setupOpts.formatters.clang-format.prepend_args =
    lib.generators.mkLuaInline ''
      function(self, ctx)
        local project = vim.fs.find({ ".clang-format", "_clang-format" }, {
          upward = true,
          path = vim.fs.dirname(ctx.filename),
        })

        if project[1] then
          return {}
        end

        local style = {
          "BasedOnStyle: LLVM",
          -- _BitInt(N) is a C23 keyword clang-format's lexer does not know, so
          -- `unsigned _BitInt(4) u4` parses as a function named _BitInt taking
          -- (4). That is not merely unaligned: one such line poisons the whole
          -- consecutive run, and plain `uint8_t u8;` beside it stops aligning
          -- too. TypenameMacros is the knob that says "X(...) is a type, not a
          -- call" -- it exists for STACK_OF(T) style macros, and it happens to
          -- be the only thing that gets _BitInt parsed correctly. TypeNames,
          -- the option that sounds right, does nothing here.
          "TypenameMacros: [_BitInt]",
          "IndentWidth: " .. ctx.shiftwidth,
          "UseTab: " .. (vim.bo[ctx.buf].expandtab and "Never" or "ForIndentation"),
          "BreakBeforeBraces: Linux",
          "AlignConsecutiveMacros: {Enabled: true}",
          "AlignConsecutiveAssignments: {Enabled: true}",
          "AlignConsecutiveBitFields: {Enabled: true}",
          "AlignConsecutiveDeclarations: {Enabled: true, AlignFunctionDeclarations: true}",
        }

        return { "-style={" .. table.concat(style, ", ") .. "}" }
      end
    '';

  # Format on write, C only.
  #
  # nvf's own hook is conform's format_on_save, gated on vim.g.formatsave --
  # the global flag that vim.lsp.formatOnSave sets. Flipping it would start
  # LSP-formatting every Nix, Python and Java buffer on save too, because
  # conform's default opts fall back to the language server for any filetype
  # without a formatter. This autocmd is the narrow version: it fires on these
  # two patterns and nothing else, and leaves vim.g.formatsave false.
  #
  # lsp_format = "never" keeps clangd out of it. clangd formats too, from its
  # own style resolution, so without this a missing clang-format would quietly
  # produce differently-styled writes instead of an error.
  programs.nvf.settings.vim.luaConfigRC.c-format-on-save = ''
    vim.api.nvim_create_autocmd("BufWritePre", {
      pattern = { "*.c", "*.h" },
      callback = function(args)
        require("conform").format({
          bufnr = args.buf,
          timeout_ms = 1000,
          lsp_format = "never",
        })
      end,
    })
  '';
}

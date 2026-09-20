{ lib, pkgs, ... }:

let
  # One budget, spent by three things: clang-format's wrapping, the prototype
  # aligner's padding, and the check that keeps the two from fighting.
  columnLimit = 120;

  # clang-format, then one anchored pass to close up `) {` into `){`.
  #
  # clang-format cannot do this itself and never will without upstream work:
  # the whole Space* family has no option for the gap between ) and {, and
  # llvm-project#59744 is an open, unimplemented request for exactly it.
  # Unlike _BitInt, where TypenameMacros happened to be the right lever, there
  # is no lever here at all -- so the text gets edited after the formatter is
  # finished with it.
  #
  # Both rules are anchored to end of line, which is what makes a regex pass
  # over source code defensible. clang-format only ever leaves this brace at
  # the end of a line, so the anchor matches exactly the construct in question:
  # a string literal would have to *end its line* with `) {` to be caught, and
  # `int arr[] = {1, 2}` or `struct point p = {` never end that way. Verified
  # against both.
  #
  # else and do get the same treatment even though they have no parenthesis to
  # close against. \b keeps the keyword whole, so `int undo = 1;` is safe.
  #
  # class and namespace join struct here, and the C++ definition suffixes --
  # const, noexcept, override, final -- join else and do, since a trailing
  # `) const {` puts a keyword rather than the paren against the brace.
  # align-prototypes.py sits between them: it needs the return-type column
  # clang-format produces, and the brace rules do not care what it did.
  clang-format-tight-braces = pkgs.writeShellScript "clang-format-tight-braces" ''
    ${lib.getExe' pkgs.clang-tools "clang-format"} "$@" \
      | ${lib.getExe pkgs.python3} ${./align-prototypes.py} ${toString columnLimit} \
      | ${lib.getExe pkgs.gnused} -E '
      s/\) \{$/){/
      s/(struct|union|enum|class|namespace)( +[A-Za-z_][A-Za-z_0-9]*)? \{$/\1\2{/
      s/\b(else|do|const|noexcept|override|final) \{$/\1{/
    '
  '';
in
{
  # Column-aligned declarations, assignments, macros and bitfields on write.
  #
  # There is no alignment-only mechanism. Neovim cannot do this as you type,
  # and clang-format's Align* options only exist inside a full reformat, so
  # every save rewrites the whole buffer -- brace placement, spacing, wrapping
  # at the column limit -- not just the columns. That is the price of it.
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
  # mkForce, because nvf's clang module already points this at clang-format
  # itself. conform runs whatever `command` names, so wrapping the binary keeps
  # this a single formatter -- adding a second entry to formatters_by_ft would
  # mean redeclaring nvf's list and inheriting its merge order.
  programs.nvf.settings.vim.formatter.conform-nvim.setupOpts.formatters.clang-format.command =
    lib.mkForce "${clang-format-tight-braces}";

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
          -- clang-format has no C23 mode to switch on, so the type keywords
          -- that look like calls have to be named. Its lexer stops at C17
          -- plus GNU: `unsigned _BitInt(4) u4` parses as a function named
          -- _BitInt taking (4), and one such line poisons the entire
          -- consecutive run -- a plain `uint8_t u8;` beside it stops aligning
          -- too. TypenameMacros is the designed knob for this; upstream
          -- documents it as making an identifier behave like typeof().
          -- TypeNames, the option that sounds right, does nothing here.
          --
          -- This list is closed, not a running repair log. C has exactly four
          -- type constructs spelled `X(...)`, and clang-format already knows
          -- _Atomic and typeof; these three are the rest of the set. Nothing
          -- short of a new language standard can extend it.
          "TypenameMacros: [_BitInt, typeof_unqual, __typeof__]",
          "IndentWidth: " .. ctx.shiftwidth,
          "UseTab: " .. (vim.bo[ctx.buf].expandtab and "Never" or "ForIndentation"),
          -- Braces attached, and no space before a control statement's paren:
          -- `if(i) {`, `int foo(void) {`. The remaining space between ) and {
          -- is not removable. clang-format has no option for it -- the whole
          -- Space* family was checked -- and upstream llvm-project#59744 is an
          -- open feature request for precisely that, unimplemented. uncrustify
          -- does have the knob (sp_fparen_brace/sp_sparen_brace), but running
          -- it after clang-format costs the _BitInt typedef column: uncrustify
          -- renormalises inter-token whitespace, and since it cannot parse
          -- _BitInt it regroups those typedefs away from the plain ones. That
          -- trade was not worth one space.
          -- A case whose whole body is one statement stays on its line:
          -- `case A: return execute_CLS(chip8);`. A case that does more than
          -- one thing still breaks open, so this compacts a dispatch table
          -- without compacting real logic.
          -- Indent case labels inside the switch rather than sitting them on
          -- the switch's own column, which is the LLVM default.
          "IndentCaseLabels: true",
          "AllowShortCaseLabelsOnASingleLine: true",
          -- ...and line the bodies up once they are there. AlignCaseColons
          -- false keeps the colon against its label and pads after it, which
          -- is the same choice made everywhere else here; true would pad
          -- before the colon instead and give `case A          : return ...`.
          "AlignConsecutiveShortCaseStatements: {Enabled: true, AlignCaseColons: false}",
          -- `char* p`, not `char *p`. The star belongs to the type, and
          -- keeping it there means a parameter's type is one unbroken token
          -- run that the prototype aligner can measure and pad as a column.
          "PointerAlignment: Left",
          -- C++: put the template header on its own line. Left inline, a
          -- `template <typename T> Error store(...)` counts as a declaration
          -- for AlignConsecutiveDeclarations, and its width then sets the name
          -- column for every plain declaration around it -- a whole table of
          -- `Error` returns pushed out by one template. Breaking it is also
          -- the conventional layout, so nothing is traded for the fix.
          "BreakTemplateDeclarations: Yes",
          "BreakBeforeBraces: Attach",
          "SpaceBeforeParens: Never",
          -- There is no "wrap after N parameters" option; the only lever is a
          -- column budget, and the alignment padding is spent from the same
          -- budget. That coupling bites: at 100 a declaration that fits only
          -- once its padding is dropped gets its padding dropped, so the
          -- column silently collapses on some lines and not others. 120 clears
          -- a five-parameter prototype in this style at 101 columns, with the
          -- alignment intact and room left over.
          "ColumnLimit: ${toString columnLimit}",
          "AlignConsecutiveMacros: {Enabled: true}",
          "AlignConsecutiveAssignments: {Enabled: true}",
          "AlignConsecutiveBitFields: {Enabled: true}",
          "AlignConsecutiveDeclarations: {Enabled: true, AlignFunctionDeclarations: true}",
        }

        return { "-style={" .. table.concat(style, ", ") .. "}" }
      end
    '';

  # Format on write, C and C++.
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
      pattern = { "*.c", "*.h", "*.cpp", "*.cc", "*.cxx", "*.hpp", "*.hh", "*.hxx" },
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

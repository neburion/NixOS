{ ... }:

# rust-analyzer through rustaceanvim, plus the treesitter grammar.
#
# One line like the other languages, but two nvf defaults are doing quiet work
# behind it and should be known before this file looks unfinished:
#
#   - Formatting stays off. nvf gates vim.languages.rust.format on
#     `!lsp.enable && enableFormat`, and the LSP is on, so Rust will not format
#     on save even if enableFormat is turned on globally later. That is the
#     wanted behaviour, not an oversight -- see ./default.nix.
#   - The debugger stays off, following languages.enableDAP, which nothing in
#     editors/neovim sets. Enabling it would pull in the vscode-lldb extension,
#     since codelldb is the adapter nvf reaches for first.

{
  programs.nvf.settings.vim.languages.rust.enable = true;
}

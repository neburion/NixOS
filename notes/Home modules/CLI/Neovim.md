# Neovim

Configured via [nvf](https://github.com/notashelf/nvf) — declarative Neovim through home-manager options. The wrapper enable lives in `home-modules/dev/nvf.nix` (only neburion imports that); the per-area config lives in `home-modules/cli/neovim/`.

```
home-modules/cli/neovim/
├── default.nix      imports all
├── options.nix      basic settings (line numbers, tabstops, nix indent autocmd)
├── plugins.nix      telescope, nvim-cmp, treesitter (+ context)
├── languages.nix    LSP + per-language treesitter (clang, rust, python, nix)
├── keybinds.nix     leader maps
└── theme.nix        catppuccin mocha
```

## Options

- `number` + `relativenumber`
- `tabstop = 4`, `shiftwidth = 4`, `expandtab = true`
- Lua autocmd: for `nix` filetype, override tabstop/shiftwidth to 2

## Plugins
- Telescope (fuzzy finder)
- nvim-cmp (completion)
- Treesitter with context

## Languages
- LSP enabled
- Treesitter + language servers for: C/C++ (`clang`), Rust, Python, Nix

## Keybinds

| Map | Action |
|---|---|
| `<leader>f` | `Telescope find_files` |
| `<leader>e` | `vim.diagnostic.open_float()` |
| `<leader>t` | Open terminal in new split, enter insert mode |

## Theme

`catppuccin` / `mocha` — hardcoded, NOT theme-switcher synced. This is a deliberate exception because changing the colorscheme inside nvim requires a plugin reload that nvf doesn't expose cleanly.

## See also

- `home-modules/dev/nvf.nix` — the `programs.nvf.enable` toggle (neburion-only)
- [[Users/Overview]] — who has nvf

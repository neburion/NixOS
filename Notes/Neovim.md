## Overview
Neovim is configured via **nvf** (notashelf/nvf) — a Nix-based Neovim configuration framework. The nvf home-manager module is loaded globally for all users via `sharedModules` in the flake. It is enabled per-user with `programs.nvf.enable = true` in `users/neburion.nix`.

Config lives in `home-modules/cli/neovim/`.

## File Breakdown

| File | Purpose |
|------|---------|
| `default.nix` | Imports all sub-modules |
| `options.nix` | General editor options |
| `theme.nix` | Colorscheme |
| `plugins.nix` | Extra plugins |
| `languages.nix` | LSP + Treesitter per language |
| `keybinds.nix` | Custom keybindings |

## Theme
Catppuccin Mocha — configured in `theme.nix`:
```nix
programs.nvf.settings.vim.theme = {
  enable = true;
  name   = "catppuccin";
  style  = "mocha";
};
```

## Plugins
- **Telescope** — fuzzy finder
- **nvim-cmp** — autocompletion
- **Treesitter** — syntax highlighting + context

## Languages (LSP + Treesitter)

| Language | Module |
|----------|--------|
| C/C++ | `clang.enable = true` |
| Rust | `rust.enable = true` |
| Python | `python.enable = true` |
| Nix | `nix.enable = true` |

## Notes
- nvf handles installing language servers automatically when a language is enabled
- `enableTreesitter = true` in languages enables Treesitter for all enabled languages

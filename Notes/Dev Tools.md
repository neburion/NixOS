Configured in `home-modules/dev/`. Imported by `users/neburion.nix`.

## Compilers & Build Tools

| Package | Language/Purpose |
|---------|-----------------|
| `gcc` | C/C++ compiler |
| `python3` | Python interpreter |
| `gnumake` | Make build system |
| `cmake` | CMake build system |
| `gdb` | C/C++ debugger |
| `godot` | Game engine |

## direnv
`direnv` with `nix-direnv` — automatically loads Nix dev shells when entering a project directory with a `.envrc` / `flake.nix`.

## AI Tools
`dev/ai/default.nix` — wraps AI CLI tools with a patched `LD_LIBRARY_PATH` so they can find system libraries (cc, zlib, openssl):

| Tool | Command |
|------|---------|
| Claude Code | `claude` |
| OpenCode | `opencode` |

## Project Bootstrap Scripts
`dev/scripts/` — shell scripts for creating new projects quickly:

| Script | What it does |
|--------|-------------|
| `newc` | Bootstrap a new C project |
| `newcpp` | Bootstrap a new C++ project |
| `newpy` | Bootstrap a new Python project |

## GitHub CLI
`mkrepo` and `rmrepo` fish aliases (in [[CLI Tools]]) wrap `gh` for quick repo creation/deletion from the current directory.

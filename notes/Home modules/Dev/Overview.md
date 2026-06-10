# Dev

`home-modules/dev/` — developer tooling.

```
dev/
├── default.nix      base toolchain + direnv
├── nvf.nix          enables nvf (neovim flake) — neburion-only
├── ai/
│   └── default.nix  wrapped claude-code + opencode CLIs
└── scripts/
    ├── default.nix  imports
    ├── newc.nix     project scaffolder — C
    ├── newcpp.nix   project scaffolder — C++
    ├── newpy.nix    project scaffolder — Python
    ├── newrust.nix  project scaffolder — Rust
    └── nixflash.nix builds + flashes installer ISO
```

## `default.nix`

Installs:
- Compilers: `gcc`, `python3`
- Build tools: `gnumake`, `cmake`
- Debugger: `gdb`
- Game engine: `godot`

Enables `programs.direnv` with `nix-direnv`. Every `cd` into a dir with `.envrc` (e.g. ones created by the `new*` scaffolders) auto-loads the nix shell.

## `nvf.nix`

```nix
programs.nvf.enable = true;
```

Separate file because only neburion uses it ([[Users/Overview]]). Nululy does NOT import this.

The actual nvf config lives in [[Home modules/CLI/Neovim]] — that's imported by everyone via `cli/`, but it's inert until `programs.nvf.enable = true` is set.

## `ai/default.nix`

Wraps `claude-code` and `opencode` with `LD_LIBRARY_PATH` set to include `stdenv.cc.cc`, `zlib`, `openssl` — needed because both binaries dynamically link to system libs not on the Nix PATH by default.

The `wrapBin` helper builds a `symlinkJoin` over the original package and uses `makeWrapper` to prefix `LD_LIBRARY_PATH`. The result is dropped on PATH as plain `claude` / `opencode`.

## Scaffolders

Each `new*` script (file name = command name) creates a new project directory with:
- canonical layout (src/, tests/, etc.)
- toolchain config (Makefile, CMakeLists, shell.nix, Cargo.toml, pyproject.toml as appropriate)
- empty entry file
- `compile_commands.json` symlink (for clangd / rust-analyzer)
- `.envrc` with `use nix` and `direnv allow`d
- git init + initial commit

Usage: `newc myproj` / `newcpp myproj` / `newpy myproj` / `newrust myproj`.

## `nixflash.nix`

Builds the installer ISO ([[Hosts/installer]]) and `dd`'s it to a device:

```sh
nixflash /dev/sdb
```

Confirms first. Uses `dd … bs=4M conv=fsync oflag=direct status=progress`.

## See also

- [[Build & rebuild]]
- [[Hosts/installer]]

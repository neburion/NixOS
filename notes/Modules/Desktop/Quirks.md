# Desktop — Quirks

`modules/desktop/quirks/` — workarounds for upstream things that don't quite fit anywhere else.

| File | What it does |
|---|---|
| `electron.nix` | `nixpkgs.config.permittedInsecurePackages = [ "electron-38.8.4" ]` — Obsidian on nixpkgs 25.11 ships with electron 38 which is past upstream EOL. The allowlist is mandatory for the build to succeed. |

Tracked here (not next to Obsidian in home-modules) because `nixpkgs.config` is a system-level setting. The file comment cross-references `home-modules/desktop/apps/productivity.nix`.

Subdir exists for growth — any future "weird workaround we have to keep" goes alongside.

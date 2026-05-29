# Apps

`home-modules/desktop/apps/` — user-facing apps, one capability per file.

| File | Apps | Notes |
|---|---|---|
| `browser.nix` | zen-browser | Pulled in via flake input `zen-browser`, version-pinned in `flake.lock` |
| `comms.nix` | signal-desktop, vesktop | One chat capability — two implementations |
| `files.nix` | nautilus | Also registers `inode/directory` mime as Nautilus |
| `media.nix` | loupe, celluloid, spotify, obs-studio | All media (viewer, player, music, recording). Also registers `image/{png,jpeg,gif,webp,svg+xml}` mime as Loupe |
| `productivity.nix` | obsidian, keepassxc | Notes, password manager |

`default.nix` imports all five.

## On bundling

`comms.nix` and `media.nix` bundle multiple apps per file because they share a capability concept. Pattern set by [[Home modules/CLI/AppImage Compression Flatpak]]'s `compression.nix` (three codec tools as one "compression" capability). See [[Principles]] for the rule.

## Hyprland bindings

[[Home modules/Desktop/WM/Hyprland]]'s `programs.nix` declares variables (`$webBrowser`, `$discord`, `$musicPlayer`, …) that map back to these apps; `keybinds.nix` uses them.

| Key | App |
|---|---|
| `SUPER+B` | zen |
| `SUPER+C` | signal |
| `SUPER+D` | vesktop |
| `SUPER+F` | nautilus |
| `SUPER+N` | obsidian |
| `SUPER+M` | spotify |
| `SUPER+P` | keepassxc |

See [[Home modules/Desktop/WM/Hyprland]] for the full keybind list.

## See also

- [[Modules/Desktop/Quirks]] — electron-38 allowlist needed for Obsidian

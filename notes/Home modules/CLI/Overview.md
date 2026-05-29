# CLI overview

`home-modules/cli/` — terminal tools for every user.

```
cli/
├── default.nix        imports below + btop, fastfetch, tree
├── appimage.nix       appimage-run
├── compression.nix    p7zip, unrar, unzip
├── fish.nix           shell config (prompt, aliases, functions)
├── flatpak.nix        adds flathub remote on first activation
├── git.nix            user.name/email, gh CLI
├── superfile.nix      TUI file manager + theme sync
└── neovim/            nvf config (multiple files)
```

`default.nix` imports everything; the `home.packages` in default itself adds `btop` / `fastfetch` / `tree`.

## Notes

- [[Home modules/CLI/Fish]] — login shell hyprland-launch, prompt, aliases
- [[Home modules/CLI/Git]] — user identity + `gh` CLI
- [[Home modules/CLI/Superfile]] — file manager with theme-synced palette
- [[Home modules/CLI/Neovim]] — nvf-based config
- [[Home modules/CLI/AppImage Compression Flatpak]] — the small-package files

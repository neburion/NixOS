Configured in `home-modules/cli/`. Imported by all users via `users/neburion.nix`.

## Fish Shell
`cli/fish.nix` — fish is also enabled system-wide in `hosts/pod042/configuration.nix`.

### Aliases

| Alias | Command |
|-------|---------|
| `rebuild` | `sudo nixos-rebuild switch --flake ~/NixOS#pod042` |
| `trebuild` | `sudo nixos-rebuild test --flake ~/NixOS#pod042` |
| `update` | `nix flake update + rebuild` |
| `cdnixos` | `cd ~/NixOS` |
| `spf` | `superfile` |
| `sspf` | `sudo superfile` |
| `cd-dev` | `cd ~/Projects/Dev` |
| `mkrepo` | Create GitHub repo from current directory and push |
| `rmrepo` | Remove origin remote and delete GitHub repo |

### Prompt
Custom prompt format: `user@host:dir$ ` — username and directory in catppuccin mauve (`#cba6f7`).

## Git
`cli/git.nix` — standard git configuration.

## Superfile
`cli/superfile.nix` — TUI file manager. Launched with `spf` or `sspf` for root.

## Other CLI Packages
Installed in `cli/default.nix`:

| Package | Purpose |
|---------|---------|
| `btop` | System monitor |
| `fastfetch` | System info |
| `tree` | Directory tree |
| `p7zip` / `unrar` / `unzip` | Archive tools |
| `appimage-run` | Run AppImages on NixOS |

## Flatpak
A home-manager activation script adds the Flathub remote on first run:
```bash
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```
Flatpak service is enabled system-wide in `modules/desktop/default.nix`.

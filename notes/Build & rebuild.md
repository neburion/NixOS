# Build & rebuild

## Fish aliases (`home-modules/cli/fish.nix`)

| Alias | Expands to |
|---|---|
| `cdnixos` | `cd $HOME/NixOS` |
| `rebuild` | `sudo nixos-rebuild switch --flake $HOME/NixOS#pod042` |
| `trebuild` | `sudo nixos-rebuild test --flake $HOME/NixOS#pod042` — same as rebuild but doesn't add a boot entry |
| `update` | `sudo nix flake update` then `sudo nixos-rebuild switch …#pod042` |

## Manual commands

```sh
# Build without switching (sanity check)
nix build .#nixosConfigurations.pod042.config.system.build.toplevel

# Dry-run (resolves derivations, doesn't build)
nix build --dry-run .#nixosConfigurations.pod042.config.system.build.toplevel

# Check flake evaluates without building anything
nix flake check --no-build

# Lock-file management
nix flake update                    # update all inputs
nix flake update nixpkgs            # update single input
nix flake lock --update-input nvf   # explicit form
```

## Installer ISO

Build the live USB installer for fresh installs of pod042:

```sh
nix build .#nixosConfigurations.installer.config.system.build.isoImage
nixflash /dev/sdX        # flashes the built ISO to the given device
```

`nixflash` is a fish-callable helper from [[Home modules/Dev/Overview]]. See [[Hosts/installer]] for the install flow.

## After dirty-tree edits

`nix flake check` will warn `Git tree '/home/neburion/NixOS' is dirty` if there are uncommitted changes. New untracked `.nix` files are invisible to the flake until staged with at least `git add -N`. Symptom: "No such file or directory" pointing at a file you just wrote.

## Generation management

```sh
sudo nix-collect-garbage --delete-older-than 14d    # matches the gc setting
nix-env --list-generations --profile /nix/var/nix/profiles/system
```

Automatic GC is configured in `modules/core/nix.nix` (`weekly`, `--delete-older-than 14d`).

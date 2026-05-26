## Overview
The flake is the single entry point for the entire config. It defines all external inputs and exposes NixOS system configurations.

## Inputs

| Input | Source | Purpose |
|-------|--------|---------|
| `nixpkgs` | `nixos-25.11` | Main package set |
| `home-manager` | `release-25.11` | User environment management |
| `zen-browser` | `youwen5/zen-browser-flake` | Zen browser (not in nixpkgs) |
| `nvf` | `notashelf/nvf` | Neovim configuration framework |
| `disko` | `nix-community/disko` | Declarative disk partitioning |

All inputs follow `nixpkgs` to avoid duplicate package sets.

## `mkSystem` Helper

```nix
mkSystem = { host, system ? "x86_64-linux", users }:
```

Wraps `nixpkgs.lib.nixosSystem` with:
- Disko module
- The host's `configuration.nix`
- Home-manager as a NixOS module
- `sharedHMConfig` applied to all users

**`sharedHMConfig`** sets:
- `useGlobalPkgs = true` — home-manager uses the system nixpkgs
- `useUserPackages = true` — user packages go into the system profile
- `extraSpecialArgs` — passes `zen-browser` flake into home-manager modules
- `sharedModules` — loads the `nvf` home-manager module for all users

## Hosts

| Host | System | Users |
|------|--------|-------|
| `pod042` | x86_64-linux | neburion, nululy |

## Rebuilding

```fish
rebuild   # sudo nixos-rebuild switch --flake ~/NixOS#pod042
trebuild  # sudo nixos-rebuild test   --flake ~/NixOS#pod042
update    # nix flake update + rebuild
```

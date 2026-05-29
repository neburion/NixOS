# installer

Live USB image for bootstrapping a fresh pod042. Built from `hosts/installer/`.

## Files

| File | Purpose |
|---|---|
| `configuration.nix` | Imports nixpkgs' `installation-cd-minimal.nix` + adds git/rclone/p7zip/jq + bundles `nixinstall` script + `disko.nix` as etc-resource |
| `nixinstall.sh` | The interactive installer script — prompts for target disk, runs disko, clones the config from GitHub, runs `nixos-install` |
| `disko.nix` | Disko disk layout (1 GiB EFI vfat boot, 17 GiB swap, rest ext4 root) — accepts `disk` arg |

The ISO bakes a `pkgs.writeShellScriptBin "nixinstall"` into `environment.systemPackages`, so on the live USB you can just run `nixinstall`.

## Build & flash

```sh
nix build .#nixosConfigurations.installer.config.system.build.isoImage
nixflash /dev/sdX    # nixflash builds + flashes in one go; see Dev/Overview
```

## Install flow

Booted from the USB:
1. `nixinstall` lists disks, asks for target
2. `disko --mode destroy,format,mount /etc/nixinstall-disko.nix --arg disk "/dev/nvme0n1"` wipes + partitions + mounts
3. `git clone https://github.com/neburion/NixOS /mnt/etc/nixos`
4. `nixos-install --flake /mnt/etc/nixos#pod042 --no-root-passwd`

## What it doesn't include

The installer ISO does NOT include disko as a NixOS module of the live system — disko is invoked via `nix run` during installation. The installer also does NOT import `modules/` or home-manager.

## See also

- [[Hosts/pod042]] — the system being installed
- `flake.nix` — the inline `installer` definition (separate from `mkSystem`)

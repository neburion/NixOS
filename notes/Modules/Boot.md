# Boot

`modules/boot/grub-efi.nix`. Standalone subdir.

- `boot.loader.efi.canTouchEfiVariables = true`
- GRUB on `nodev` with EFI support
- `useOSProber = true` — picks up dual-boot OSes
- `configurationLimit = 10` — keep 10 generations in the menu

To switch to systemd-boot or another bootloader on a future host, drop a sibling file in `modules/boot/` and import only the one you want (`modules/boot/systemd-boot.nix`), not the whole subdir.

## See also

- [[Build & rebuild]] for managing generations

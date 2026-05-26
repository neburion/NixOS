{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "nixflash" ''
      set -euo pipefail
      DEVICE="''${1:-}"
      [[ -z "$DEVICE" ]] && { printf 'Usage: nixflash <device>  (e.g. nixflash /dev/sdb)\n'; exit 1; }
      [[ ! -b "$DEVICE" ]] && { printf 'Error: %s is not a block device\n' "$DEVICE"; exit 1; }

      printf 'Building NixOS installer ISO (this may take a while)...\n'
      ISO_DIR=$(nix build "$HOME/NixOS#nixosConfigurations.installer.config.system.build.isoImage" \
        --no-link --print-out-paths)
      ISO="$ISO_DIR/iso/$(ls "$ISO_DIR/iso/")"
      printf 'Built: %s\n\n' "$ISO"

      printf 'WARNING: ALL DATA on %s will be erased.\n' "$DEVICE"
      read -rp "Flash to $DEVICE? [y/N] " confirm
      [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { printf 'Aborted.\n'; exit 0; }

      printf 'Flashing...\n'
      sudo dd if="$ISO" of="$DEVICE" bs=4M conv=fsync oflag=direct status=progress
      sync
      printf 'Done. USB is ready to boot.\n'
    '')
  ];
}

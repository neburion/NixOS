{ pkgs, osConfig, ... }:

# `nixflash <device>` — build the installer ISO and dd it to a USB stick.
#
# Lived in iso/nixflash.nix until now, which meant the tool for *making* the
# live USB only existed once you had already booted that live USB. It's
# workstation tooling: any fleet host should be able to write a rescue stick.

let
  inherit (import ./lib.nix { inherit osConfig; }) cloudFlake;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "nixflash";
      runtimeInputs = with pkgs; [ nix coreutils ];
      text = ''
        DEVICE="''${1:-}"
        [[ -z "$DEVICE" ]] && { printf 'Usage: nixflash <device>  (e.g. nixflash /dev/sdb)\n'; exit 1; }
        [[ ! -b "$DEVICE" ]] && { printf 'Error: %s is not a block device\n' "$DEVICE"; exit 1; }

        printf 'Building NixOS installer ISO (this may take a while)...\n'
        ISO_DIR=$(nix build "${cloudFlake}#nixosConfigurations.installer.config.system.build.isoImage" \
          --no-link --print-out-paths)

        # Glob rather than `ls` so a filename with spaces can't split, and so
        # an empty result is caught explicitly instead of yielding "$ISO_DIR/iso/".
        shopt -s nullglob
        isos=("$ISO_DIR"/iso/*.iso)
        shopt -u nullglob
        if (( ''${#isos[@]} == 0 )); then
          printf 'Error: no .iso produced under %s/iso\n' "$ISO_DIR" >&2
          exit 1
        fi
        ISO="''${isos[0]}"
        printf 'Built: %s\n\n' "$ISO"

        printf 'WARNING: ALL DATA on %s will be erased.\n' "$DEVICE"
        read -rp "Flash to $DEVICE? [y/N] " confirm
        [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { printf 'Aborted.\n'; exit 0; }

        printf 'Flashing...\n'
        sudo dd if="$ISO" of="$DEVICE" bs=4M conv=fsync oflag=direct status=progress
        sync
        printf 'Done. USB is ready to boot.\n'
      '';
    })
  ];
}

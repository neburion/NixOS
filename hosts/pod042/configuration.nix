{ ... }:

# pod042 — the laptop. The only host with a display.

{
  imports = [
    ./hardware
    ./generated/hardware.nix

    ../../modules/system/presets/base.nix
    ../../modules/system/presets/tailnet.nix
    ../../modules/system/presets/laptop.nix
    ../../modules/system/presets/graphical.nix
    ../../modules/system/presets/cloudflare.nix

    ../../modules/system/boot/limine.nix
    ../../modules/system/hardware/nvidia.nix
    ../../modules/system/network/wifi/bell096.nix
    ../../modules/system/network/avahi.nix
    ../../modules/system/network/syncthing.nix
    ../../modules/system/services/backup/restic.nix

    # System halves of modules that live with their owner under modules/home.
    ../../modules/home/cli/shell/fish/system.nix
    ../../modules/home/cli/flatpak/system.nix
    ../../modules/home/gaming/launchers/steam/system.nix
    ../../modules/home/peripherals/logitech/system.nix
    ../../modules/home/desktop/glass/wm/system.nix
    ../../modules/home/desktop/glass/components/wayvnc/system.nix

    ../../users/neburion
  ];
}

{ ... }:

# pod042 — the laptop. The only host in the fleet with a display.

{
  imports = [
    ./hardware
    ./generated/hardware.nix

    ../../modules/system/core/nix.nix
    ../../modules/system/core/locale.nix
    ../../modules/system/core/sops.nix
    ../../modules/system/core/sudo.nix
    ../../modules/system/core/fish.nix

    ../../modules/system/boot/limine.nix

    ../../modules/system/hardware/audio.nix
    ../../modules/system/hardware/bluetooth.nix
    ../../modules/system/hardware/brightness.nix
    ../../modules/system/hardware/lid.nix
    ../../modules/system/hardware/logitech.nix
    ../../modules/system/hardware/nvidia.nix
    ../../modules/system/hardware/power-profiles.nix
    ../../modules/system/hardware/touchpad.nix

    ../../modules/system/network/avahi.nix
    ../../modules/system/services/cloudflare/email.nix
    ../../modules/system/services/cloudflare/r2.nix
    ../../modules/system/services/cloudflare/tunnel.nix
    ../../modules/system/network/networkmanager.nix
    ../../modules/system/network/wifi/bell096.nix
    ../../modules/system/network/ssh.nix
    ../../modules/system/network/syncthing.nix
    ../../modules/system/network/tailnet-hosts.nix
    ../../modules/system/network/tailscale.nix

    ../../modules/system/session

    ../../modules/system/services/restic.nix

    ../../modules/tools/fleet/hooks.nix
    ../../modules/system/services/cloudflare/reconcile.nix

    ../../users/neburion
  ];
}

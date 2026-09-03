{ ... }:

{
  imports = [
    ./hardware
    ./policy
    ./generated/hardware.nix

    ../../modules/system/nixos.nix
    ../../modules/system/security/sops.nix
    ../../modules/system/security/sudo.nix
    ../../modules/system/backup/restic.nix
    ../../modules/system/rebuild-hooks/registry.nix
    ../../modules/system/rebuild-hooks/cf-reconcile.nix
    ../../modules/system/boot/limine.nix
    ../../modules/system/hardware/nvidia.nix
    ../../modules/system/hardware/touchpad.nix
    ../../modules/system/hardware/brightness.nix
    ../../modules/system/hardware/lid.nix
    ../../modules/system/hardware/logitech.nix
    ../../modules/system/locale.nix
    ../../modules/system/networking/networkmanager.nix
    ../../modules/system/networking/ssh.nix
    ../../modules/system/networking/tailscale.nix
    ../../modules/system/networking/tailnet-hosts.nix
    ../../modules/system/networking/avahi.nix
    ../../modules/system/networking/cloudflare-tunnel.nix
    ../../modules/system/networking/cloudflare-email.nix
    ../../modules/system/networking/cloudflare-r2.nix
    ../../modules/system/networking/localsend-firewall.nix
    ../../modules/system/networking/syncthing.nix
    ../../modules/system/bluetooth.nix
    ../../modules/system/audio.nix
    ../../modules/system/flatpak.nix
    ../../modules/system/power-profiles.nix
    ../../modules/system/desktop

    ../../users/neburion
  ];
}

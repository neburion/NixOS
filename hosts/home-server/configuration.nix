{ ... }:

# home-server — the family's box. Print and scan, and it stays boring on
# purpose: the household depends on it, so it is not where anything gets tried
# out. See personal-server for the other half of that split.

{
  imports = [
    ./hardware
    ./policy
    ./generated/hardware.nix

    ../../modules/system/core/nix.nix
    ../../modules/system/core/locale.nix
    ../../modules/system/core/sops.nix
    ../../modules/system/core/sudo.nix
    ../../modules/system/core/console.nix
    ../../modules/system/core/fish.nix

    ../../modules/system/boot/systemd-boot.nix

    ../../modules/system/hardware/always-on.nix
    ../../modules/system/hardware/power-profiles.nix

    ../../modules/system/network/cloudflare-email.nix
    ../../modules/system/network/cloudflare-r2.nix
    ../../modules/system/network/cloudflare-tunnel.nix
    ../../modules/system/network/networkmanager.nix
    ../../modules/system/network/ssh.nix
    ../../modules/system/network/tailnet-hosts.nix
    ../../modules/system/network/tailscale.nix

    ../../modules/system/services/printing

    ../../modules/tools/hooks.nix
    ../../modules/tools/reconcilers/cf.nix

    ../../users/server-admin
  ];
}

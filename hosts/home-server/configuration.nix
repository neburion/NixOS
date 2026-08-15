{ ... }:

{
  imports = [
    ./hardware-layout

    ../../modules/system/nixos.nix
    ../../modules/system/security/sops.nix
    ../../modules/system/security/sudo.nix
    ../../modules/system/rebuild-hooks/registry.nix
    ../../modules/system/rebuild-hooks/cf-reconcile.nix
    ../../modules/system/locale.nix
    ../../modules/system/boot/systemd-boot.nix
    ../../modules/system/networking/networkmanager.nix
    ../../modules/system/networking/ssh.nix
    ../../modules/system/networking/tailscale.nix
    ../../modules/system/networking/tailnet-hosts.nix
    ../../modules/system/networking/cloudflare-tunnel.nix
    ../../modules/system/networking/cloudflare-email.nix
    ../../modules/system/networking/cloudflare-r2.nix
    ../../modules/system/always-on.nix
    ../../modules/system/console-autologin.nix
    ../../modules/system/power-profiles.nix
    ../../modules/system/printing

    ../../users/home-admin

    ./hardware-configuration.nix
  ];
}

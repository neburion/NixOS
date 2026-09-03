{ ... }:

# home-server — the family's box. Print and scan, and it stays boring on
# purpose: the household depends on it, so it is not where things get tried.

{
  imports = [
    ./hardware
    ./generated/hardware.nix

    ../../modules/system/presets/base.nix
    ../../modules/system/presets/tailnet.nix
    ../../modules/system/presets/headless.nix

    ../../modules/system/boot/systemd-boot.nix
    ../../modules/system/network/wifi/bell096.nix
    ../../modules/system/services/printing/canon
    ../../modules/system/services/printing/web-ui.nix
    ../../modules/system/services/cloudflare/tunnel.nix
    ../../modules/system/services/cloudflare/email.nix
    ../../modules/system/services/cloudflare/r2.nix
    ../../modules/system/services/cloudflare/reconcile.nix

    ../../modules/home/cli/shell/fish/system.nix

    ../../users/server-admin
  ];
}

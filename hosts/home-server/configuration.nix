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
    # Print and scan moved to personal-server on 2026-10-05, while this box was
    # unreachable. The printer is physically on that machine now, so these stay
    # out until it comes back and someone decides which box owns the MFP.
    #
    # Its old tunnel for printer.azuresalt.app is still declared upstream —
    # cf-reconcile warns about rules that disappear rather than deleting them —
    # and `cloudflared-printer-azuresalt-app` is still in secrets/home-server.yaml.
    # Both are inert now the DNS record points at personal-server's tunnel.
    #
    #   ../../modules/system/services/printing/canon.nix
    #   ../../modules/system/services/printing/web-ui.nix
    ../../modules/system/services/cloudflare/tunnel.nix
    ../../modules/system/services/cloudflare/email.nix
    ../../modules/system/services/cloudflare/r2.nix
    ../../modules/system/services/cloudflare/reconcile.nix

    ../../modules/home/cli/shell/fish/system.nix

    ../../users/server-admin
  ];
}

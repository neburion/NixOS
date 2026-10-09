{ ... }:

# personal-server — my own self-hosting box (old laptop), deliberately kept
# separate from `home-server`, which is family infrastructure.
#
# The split is about blast radius and audience, not capability: home-server
# runs things the household depends on (print/scan), so it should be boring
# and stay up. This host is where my own services live and where I break
# things. Nothing here is a dependency of anything there — see the fleet
# principle in ARCHITECTURE.md.
#
# Base: boot, network, tailnet, ssh, secrets, admin user.
#
# The services themselves are no longer modules here. They live in their own
# repos and are deployed by modules/system/apps/platform.nix, which reads an
# app.json out of each one; which repos this host runs is declared in
# policy/apps.nix. Currently the media tracker (:8778) and the fleet dashboard
# (:8779), both tailnet-only, both without a login — the reasoning for that
# pairing is in policy/apps.nix.
#
# So this host declares no Cloudflare tunnels at all any more. The two modules
# are still imported: cloudflared costs nothing while nothing is declared, and
# cf-reconcile is a fleet-wide rebuild hook rather than a thing this host wants
# for itself. Publishing something from here again is a `public = true` away.

{
  imports = [
    ./hardware
    ./policy
    ./generated/hardware.nix

    ../../modules/system/presets/base.nix
    ../../modules/system/presets/tailnet.nix
    ../../modules/system/presets/headless.nix

    ../../modules/system/boot/systemd-boot.nix
    ../../modules/system/network/wifi/bell096.nix
    # Print and scan, moved here from home-server on 2026-10-05: home-server
    # stopped answering and this is the box that is up. The Canon MF3010 plugs
    # into this machine's USB now.
    ../../modules/system/services/printing/canon.nix
    ../../modules/system/services/printing/web-ui.nix

    ../../modules/system/services/cloudflare/tunnel.nix
    ../../modules/system/services/cloudflare/reconcile.nix
    ../../modules/system/services/app-platform

    ../../modules/home/cli/shell/fish/system.nix

    ../../users/server-admin
  ];
}

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
# policy/apps.nix. Currently the media tracker (:8778) and the
# Elden Ring ledger (:8777), both tailnet-only with public Cloudflare tunnels.
#
# apps/paisa.nix is the exception, imported directly: expense tracking over an
# hledger journal, :8779. It is a nixpkgs binary rather than a repo of ours, so
# there is no app.json to read and nothing for the platform to deploy — only a
# unit and a state directory. It follows the platform's shape by hand.

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
    ../../modules/system/services/cloudflare/tunnel.nix
    ../../modules/system/services/cloudflare/reconcile.nix
    ../../modules/system/services/backup/restic.nix
    ../../modules/system/services/paisa
    ../../modules/system/services/app-platform

    ../../modules/home/cli/shell/fish/system.nix

    ../../users/server-admin
  ];
}

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
# hardware-layout/apps-layout.nix. Currently the media tracker (:8778) and the
# Elden Ring ledger (:8777), both tailnet-only with public Cloudflare tunnels.
#
# apps/paisa.nix is the exception, imported directly: expense tracking over an
# hledger journal, :8779. It is a nixpkgs binary rather than a repo of ours, so
# there is no app.json to read and nothing for the platform to deploy — only a
# unit and a state directory. It follows the platform's shape by hand.

{
  imports = [
    ./hardware-layout

    ../../modules/system/nixos.nix
    ../../modules/system/backup/restic.nix
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
    ../../modules/system/always-on.nix
    ../../modules/system/console-autologin.nix
    ../../modules/system/power-profiles.nix
    ../../modules/system/apps/platform.nix
    ../../modules/system/apps/paisa.nix

    ../../users/server-admin

    ./hardware-configuration.nix
  ];
}

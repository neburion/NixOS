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
# Services get added as their own modules under modules/system/, one import
# line each. Currently: the Elden Ring completion tracker (tailnet-only :8777)
# and the reading tracker (tailnet-only :8778).

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
    ../../modules/system/always-on.nix
    ../../modules/system/console-autologin.nix
    ../../modules/system/power-profiles.nix
    ../../modules/system/elden-ring-tracker
    ../../modules/system/media-tracker

    ../../users/server-admin

    ./hardware-configuration.nix
  ];
}

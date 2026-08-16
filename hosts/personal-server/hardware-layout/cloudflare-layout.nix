{ ... }:

# Cloudflare Tunnel declarations for personal-server. Behavior module:
# modules/system/networking/cloudflare-tunnel.nix.
#
# cloudflared runs on this host and dials 127.0.0.1:8777 from the inside, so
# the tunnel needs no firewall rule — the tracker's only open port stays
# tailnet-scoped (see modules/system/elden-ring-tracker/service.nix).
#
# `rebuild` runs cf-reconcile first, which creates the tunnel, writes the
# CNAME, drops the credentials into secrets/personal-server.yaml (encrypted),
# and records hostname → UUID in cf-tunnels.lock.json. Commit both files after.
#
# NOT declarative, and easy to forget: the Cloudflare Access policy that gates
# who can reach the hostname. cf-reconcile does not manage Access — a tunnel
# with no policy is open to the entire internet.
#
# Unlike printer.azuresalt.app on home-server, this hostname does not depend on
# that policy being right: the tracker carries its own HTTP Basic Auth from the
# `elden-ring-password` sops secret, and refuses to start at all if the
# credential fails to load. Access is the outer gate, not the only one. Set it
# up anyway — defence in depth is the point, and it keeps scanners off the app.

{
  config.cloudflare.declaredTunnels = {
    "eldenring.azuresalt.app" = { service = "http://localhost:8777"; };
  };
}

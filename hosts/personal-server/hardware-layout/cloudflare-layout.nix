{ ... }:

# Cloudflare Tunnel declarations for personal-server. Behavior module:
# modules/system/networking/cloudflare-tunnel.nix.
#
# Empty on purpose — the host runs no public services yet. The wiring is
# already in place, so exposing one later is a single entry here:
#
#   config.cloudflare.declaredTunnels = {
#     "thing.azuresalt.app" = { service = "http://localhost:8080"; };
#   };
#
# The next `rebuild` runs cf-reconcile, which creates the tunnel, writes the
# CNAME, drops the credentials into secrets/personal-server.yaml (encrypted),
# and records hostname → UUID in cf-tunnels.lock.json. Commit both files after.
#
# NOT declarative, and easy to forget: the Cloudflare Access policy that gates
# who can reach the hostname. cf-reconcile does not manage Access — a tunnel
# with no policy is open to the entire internet. Configure it in the dashboard
# before pointing a tunnel at anything that lacks its own auth.
#
# With no tunnels declared, cloudflare-tunnel.nix leaves services.cloudflared
# disabled entirely; only the CLI package is installed.

{
  config.cloudflare.declaredTunnels = { };
}

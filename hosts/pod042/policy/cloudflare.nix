{ ... }:

# Cloudflare Tunnel declarations for pod042. Behavior module:
# modules/system/networking/cloudflare-tunnel.nix.
#
# pod042 has no publicly-exposed services right now — keep empty.
# To add one:
#   config.cloudflare.declaredTunnels."<hostname>.azuresalt.app" = {
#     service = "http://localhost:<port>";
#   };
# Then `rebuild` (locally) or `rebuild <target>` (elsewhere) — the cf-reconcile
# hook creates the tunnel + DNS record via API, writes credentials into
# secrets/pod042.yaml, updates cf-tunnels.lock.json, then nixos-rebuild
# ships the whole thing.

{
  config.cloudflare.declaredTunnels = { };
}

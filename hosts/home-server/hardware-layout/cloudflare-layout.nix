{ ... }:

# Cloudflare Tunnel declarations for home-server. Behavior module:
# modules/system/networking/cloudflare-tunnel.nix.
#
# Print/scan web UI is on :80. Gating: Cloudflare Access policy
# (email OTP → paperkite@posteo.com) must be configured in the Cloudflare
# dashboard before this goes live — server.py has no auth of its own.

{
  config.cloudflare.declaredTunnels = {
    "printer.azuresalt.app" = { service = "http://localhost:80"; };
  };
}

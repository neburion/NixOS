{ ... }:

# Cloudflare Tunnel declarations for personal-server. Behavior module:
# modules/system/networking/cloudflare-tunnel.nix.
#
# cloudflared runs on this host and dials 127.0.0.1 from the inside, so these
# tunnels need no firewall rules — both trackers' only open ports stay
# tailnet-scoped (see modules/system/{elden-ring,reading}-tracker/service.nix).
#
# `rebuild` runs cf-reconcile first, which creates the tunnel, writes the
# CNAME, drops the credentials into secrets/personal-server.yaml (encrypted),
# and records hostname → UUID in cf-tunnels.lock.json. Commit both files after.
#
# NOT declarative, and easy to forget: the Cloudflare Access policy that gates
# who can reach the hostname. cf-reconcile does not manage Access — a tunnel
# with no policy is open to the entire internet.
#
# Unlike printer.azuresalt.app on home-server, these hostnames do not depend on
# that policy being right: both trackers carry their own HTTP Basic Auth from a
# sops secret, and refuse to start at all if the credential fails to load.
# Access is the outer gate, not the only one. Set it up anyway — defence in
# depth is the point, and it keeps scanners off the app.
#
# reading.azuresalt.app matters more than eldenring.azuresalt.app here. The
# Elden Ring tracker's worst case is a wiped playthrough that seed.py can
# rebuild; the reading tracker's POST surface includes deleting a series, which
# takes its chapter history with it and cannot be undone. Its Basic Auth
# password is also short. Put an Access policy in front of this one.

{
  config.cloudflare.declaredTunnels = {
    "eldenring.azuresalt.app" = { service = "http://localhost:8777"; };
    "reading.azuresalt.app" = { service = "http://localhost:8778"; };
  };
}

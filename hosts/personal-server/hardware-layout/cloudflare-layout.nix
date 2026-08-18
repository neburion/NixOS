{ ... }:

# Cloudflare Tunnel declarations for personal-server. Behavior module:
# modules/system/networking/cloudflare-tunnel.nix.
#
# cloudflared runs on this host and dials 127.0.0.1 from the inside, so these
# tunnels need no firewall rules — both trackers' only open ports stay
# tailnet-scoped (see modules/system/{elden-ring,reading}-tracker/service.nix).
# Three hostnames, two services: media and reading both reach :8778.
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
# media.azuresalt.app — and reading.azuresalt.app, which is the same service —
# matters more than eldenring.azuresalt.app here. The Elden Ring tracker's worst
# case is a wiped playthrough that seed.py can rebuild; this one's POST surface
# includes deleting a series, which takes its chapter history with it and cannot
# be undone. Its Basic Auth password is also short. Put an Access policy in
# front of these two.

{
  config.cloudflare.declaredTunnels = {
    "eldenring.azuresalt.app" = { service = "http://localhost:8777"; };

    # The shelf answers on both names. `media` is what it is now — it tracks
    # anime, shows, films and games alongside the reading — and `reading` stays
    # because it is in a phone's home screen and a bookmark bar, and breaking
    # those to make a point about naming is not worth it. Two tunnels, one
    # service, no redirect: a redirect would send the browser to a hostname the
    # saved Basic Auth credential is not scoped to, and ask for the password
    # again on every visit.
    "media.azuresalt.app" = { service = "http://localhost:8778"; };
    "reading.azuresalt.app" = { service = "http://localhost:8778"; };
  };
}

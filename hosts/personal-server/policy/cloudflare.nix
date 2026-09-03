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
  # Empty on purpose. Every hostname this host answers to belongs to an app,
  # and each app declares its own in the `urls` of its app.json — the platform
  # module turns those into declaredTunnels entries, so eldenring, media and
  # reading are all still here, just not written down twice.
  #
  # paisa.azuresalt.app is here too, by the same reasoning applied one level
  # down: it is not a platform app, so it declares its own tunnel from
  # modules/system/apps/paisa.nix, next to the port it routes to. Writing the
  # hostname here as well would mean the port lives in two files and drifts in
  # one of them.
  config.cloudflare.declaredTunnels = { };
}

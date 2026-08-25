{ inputs, ... }:

# Which projects this host runs. Behavior module:
# modules/system/apps/platform.nix.
#
# Each entry is a flake input holding a repo with an `app.json` at its root.
# That manifest is the whole interface — port, URLs, secret names, whether it
# wants a state directory — and the platform turns it into a systemd unit, a
# system user, /var/lib/<name>, the credential wiring, the tailnet firewall
# rule and the Cloudflare tunnel. Nothing about either project is described
# here, which is the point: they are programs, and this repo describes machines.
#
# An entry lands in the environment layer rather than the manifest because it
# is a per-host fact — *this* box runs these — the same way cloudflare-layout
# declares which hostnames it answers to.
#
# Updating an app is `nix flake update <name>` from this repo, then `rebuild
# personal-server`. The pin means the running version belongs to the system
# generation: `nixos-rebuild --rollback` takes the app back with it.
#
# Their secrets live in secrets/personal-server.yaml under `<app>-<key>`, which
# is the naming the platform enforces — `media-tracker-password` and
# `elden-ring-tracker-password` today. A repo can only ever name its own.

{
  config.apps.instances = {
    media-tracker = inputs.media-tracker;
    elden-ring-tracker = inputs.elden-ring-tracker;
  };
}

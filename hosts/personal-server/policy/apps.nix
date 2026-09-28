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
# ── Why both of these are tailnet-only and have no login ─────────────────────
#
# They used to sit at media.azuresalt.app and dashboard.azuresalt.app behind a
# password, and both halves of that were doing the same job badly. The password
# existed because the hostname was public; the hostname was public so the pages
# could be opened from a phone — and the phone is on the tailnet already. So the
# tunnel bought nothing that Tailscale was not giving, and cost a login screen,
# two sops secrets per app, a cookie whose lifetime had to be reasoned about,
# and a public URL that anyone could knock on for as long as they liked.
#
# Dropping the URL is what makes dropping the login safe, and the platform
# enforces that order: `withoutSecrets = [ "password" ]` with `public = true`
# fails evaluation rather than rebuilding. The firewall rule on tailscale0 is
# now the only gate, which is fine, because it is the same gate that has always
# stood in front of ssh on these boxes.
#
# The apps meet this halfway of their own accord. Both compute `AUTH_ON` from
# whether a password credential arrived, so withholding it turns the login off
# with no change in their repos — and both then refuse to bind anything but
# loopback unauthenticated, which is exactly the check that catches this being
# done by accident. `MT_ALLOW_NO_AUTH` / `DASH_ALLOW_NO_AUTH` is the override
# they document for meaning it, and it is set here, on the host that decided.
#
# What is left in secrets/personal-server.yaml is what the dashboard needs to
# do its job rather than to guard it: the Porkbun pair and the Cloudflare token
# it reads registrar and zone state with. The retired `*-password` and
# `*-username` entries are no longer declared by anything and can be dropped
# with `sops unset`; they are dead weight, not a leak.
#
# The dashboard is the odd one out in the other direction too: it stores nothing
# and serves no data of its own, it only reads the fleet-status agent on each
# host. It is here rather than on home-server because home-server is the
# family's box and stays boring — which does mean this host's own outage takes
# the dashboard with it. A dead page is personal-server's down signal; nothing
# else reports it. That signal is now only visible from the tailnet, which is
# the one thing this change genuinely costs.

{
  config.apps.instances = {
    media-tracker = {
      src = inputs.media-tracker;
      public = false;
      withoutSecrets = [ "password" "username" ];
      extraEnv.MT_ALLOW_NO_AUTH = "1";
    };

    dashboard = {
      src = inputs.dashboard;
      public = false;
      withoutSecrets = [ "password" "username" ];
      extraEnv.DASH_ALLOW_NO_AUTH = "1";
    };
  };
}

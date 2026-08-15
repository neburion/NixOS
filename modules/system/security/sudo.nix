{ ... }:

# Sudo cache tuning for the fleet's reconciler flow.
#
# Default NixOS sudo scopes the timestamp cache per-TTY, which means a
# subprocess spawned by an already-authenticated shell has to re-auth.
# `rebuild` primes sudo once, then invokes pre-hooks (like cf-reconcile)
# which need their own sudo calls (to read /var/lib/sops-nix/key.txt via
# `sops --decrypt`). Without `!tty_tickets` those inner sudo calls
# reprompt or fail non-interactively.
#
# `!tty_tickets` makes the cache per-user, so `sudo -v` in the wrapper
# is enough for every subsequent sudo call within the cache lifetime
# (5 minutes by default). Extending the timeout modestly so a slow
# reconcile doesn't force a re-prompt.

{
  security.sudo.extraConfig = ''
    Defaults !tty_tickets
    Defaults timestamp_timeout=15
  '';
}

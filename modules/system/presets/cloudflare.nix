{ ... }:

# The full Cloudflare surface: tunnels, email routing, R2, and the reconciler
# that converges all three before a rebuild.
#
# Divisible on purpose — home-server takes only tunnel.nix and reconcile.nix,
# because it has no mail or buckets. This is for the host that owns the account.

{
  imports = [
    ../services/cloudflare/tunnel.nix
    ../services/cloudflare/email.nix
    ../services/cloudflare/r2.nix
    ../services/cloudflare/reconcile.nix
  ];
}

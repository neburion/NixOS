{ lib, ... }:

# Fleet-wide Cloudflare Email Routing declarations. Behavior:
# cf-reconcile (see modules/system/services/cloudflare/reconcile.nix) reads
# these options and reconciles them against the Cloudflare API on every
# rebuild.
#
# Prereqs: the destination address (where forwards go) must be verified
# via Cloudflare's UI once — CF sends a confirmation email. cf-reconcile
# warns if a declared forward target isn't verified.
#
# Rule format (per-zone):
#   { catch_all = true; forward = "you@example.com"; }
#     — forward everything for the zone
#   { local_part = "hello"; forward = "you@example.com"; }
#     — forward hello@<zone> only
#
# Deletion policy: cf-reconcile does NOT auto-delete rules that disappear
# from the config. It warns instead. Delete manually via API or dashboard.

{
  options.cloudflare.email = {
    rules = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf (lib.types.attrs));
      default = { };
      description = ''
        Email routing rules per zone. Keyed by zone name (e.g. "azuresalt.app").
        Each value is a list of rule attrsets — see module comments for format.
      '';
    };
  };

  # Current fleet declarations. Add rules here; run rebuild.
  config.cloudflare.email.rules."azuresalt.app" = [
    { catch_all = true; forward = "paperkite@posteo.com"; }
  ];
}

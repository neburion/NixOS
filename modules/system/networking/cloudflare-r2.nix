{ lib, ... }:

# Fleet-wide Cloudflare R2 bucket declarations. Behavior:
# cf-reconcile reads these options and ensures each declared bucket exists
# in Cloudflare on every rebuild.
#
# Deletion policy: cf-reconcile NEVER auto-deletes R2 buckets — the data
# loss risk is too high. If a bucket disappears from the config, the
# reconciler warns and leaves the bucket alone. Delete manually via CF
# dashboard or API when you're actually sure.
#
# Free tier limits (10GB storage, 1M Class A ops/mo, 10M Class B ops/mo,
# no egress fees). Nothing here enables paid features.

{
  options.cloudflare.r2.buckets = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        location = lib.mkOption {
          type    = lib.types.enum [ "auto" "wnam" "enam" "weur" "eeur" "apac" ];
          default = "auto";
          description = "Region hint. `auto` lets CF pick based on account.";
        };
      };
    });
    default     = { };
    description = "R2 buckets this account should have. Keyed by bucket name.";
  };

  # Current fleet declarations. Add buckets here; run rebuild.
  config.cloudflare.r2.buckets."neburion-backup" = { };
}

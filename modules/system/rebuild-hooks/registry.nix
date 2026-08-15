{ config, lib, ... }:

# Internal registry — reconciler modules (cloudflare-tunnel, r2-backup, etc.)
# contribute pre-rebuild hooks via `rebuild.preHooks.<name>`. The `rebuild`
# wrapper (see modules/home/cli/nixos-scripts/) iterates every registered
# hook in name-sorted order before invoking `nixos-rebuild switch`; a non-zero
# exit from any hook aborts the rebuild before any host is touched.
#
# Each entry is a shell-script package. The wrapper resolves each package's
# main binary via `${hook}/bin/${hook.pname or hook.name}`.
#
# Not a user-facing knob — same latitude the environment layer and the
# quickshell/theme-hooks registries get. See ARCHITECTURE.md rule 2 exceptions.

{
  options.rebuild.preHooks = lib.mkOption {
    type    = lib.types.attrsOf lib.types.package;
    default = { };
    description = ''
      Reconciler scripts run before every rebuild. Each entry is a shell
      script package (typically from pkgs.writeShellApplication). Hooks
      converge external state (Cloudflare tunnels, R2 buckets, etc.) with
      what the nix config declares, writing any resulting credentials into
      secrets/<host>.yaml via sops before nixos-rebuild ships the closure.

      Hooks run on whichever machine invokes `rebuild`, not on the target
      host — so the API tokens they read live in secrets/common.yaml, not
      on the deployment target. Non-zero exit aborts the rebuild.
    '';
  };

  # Expose every registered hook on PATH for manual debugging / one-off runs
  # (`cf-reconcile` on its own, without a full rebuild). Cheap: each hook is
  # already in the closure via the rebuild wrapper.
  config.environment.systemPackages = builtins.attrValues config.rebuild.preHooks;
}

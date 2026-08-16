{ pkgs, osConfig, ... }:

# `rebuild [host]` — switch a host to whatever is on origin/master.

let
  inherit (import ./lib.nix { inherit osConfig; })
    cloudFlake runHooks warnIfLocalDiverged;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "rebuild";
      runtimeInputs = with pkgs; [ nixos-rebuild nettools openssh git coreutils gnused ];
      text = ''
        # Prime sudo BEFORE running hooks — hooks (e.g. cf-reconcile) shell out
        # to `sudo sops --decrypt` for reading the age key, and need the cached
        # credential. Requires `Defaults !tty_tickets` in sudo config so the
        # cache survives the subshell (see modules/system/security/sudo.nix).
        sudo -Sv

        ${warnIfLocalDiverged}
        ${runHooks}

        # First non-flag arg (if any) is treated as a target hostname.
        # `--` explicitly ends target-parsing, so `rebuild -- --show-trace`
        # rebuilds locally with --show-trace instead of trying to SSH to
        # a host called `--show-trace`.
        target=""
        if [[ $# -gt 0 && "$1" != -* && "$1" != "--" ]]; then
          target="$1"
          shift
        fi
        [[ "''${1:-}" == "--" ]] && shift

        if [[ -z "$target" ]]; then
          target="$(hostname -s)"
        fi

        # --refresh forces nix to re-fetch the flake source (bypasses the
        # 1-hour tarball cache) so a `git push` immediately followed by
        # `rebuild` uses the just-pushed commit.
        if [[ "$target" != "$(hostname -s)" ]]; then
          echo "▸ remote deploy → $target (from ${cloudFlake})"
          nixos-rebuild switch \
            --flake "${cloudFlake}#$target" \
            --refresh \
            --target-host "$target" \
            --sudo \
            --no-reexec \
            "$@"
        else
          echo "▸ local rebuild → $target (from ${cloudFlake})"
          sudo nixos-rebuild switch \
            --flake "${cloudFlake}#$target" \
            --refresh \
            "$@"
        fi
      '';
    })
  ];
}

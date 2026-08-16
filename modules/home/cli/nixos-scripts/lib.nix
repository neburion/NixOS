{ osConfig }:

# NOT a module — a plain function returning shell fragments shared by the
# rebuild-family scripts. Imported explicitly:
#
#   let inherit (import ./lib.nix { inherit osConfig; }) cloudFlake runHooks;
#
# Lives here rather than in default.nix so default.nix stays pure aggregation
# (ARCHITECTURE.md rule 5).

rec {
  # Where the cloud repo lives. Change here if you migrate off GitHub
  # (Codeberg, self-hosted Forgejo, etc.).
  cloudFlake = "github:neburion/NixOS";

  # Space-separated list of hook script store paths. Each hook is a
  # writeShellApplication package; its main binary is at
  # ${hook}/bin/${hook.pname or hook.name}.
  hookInvocations = builtins.concatStringsSep " "
    (builtins.map
      (h: "${h}/bin/${h.pname or h.name}")
      (builtins.attrValues osConfig.rebuild.preHooks));

  runHooks = ''
    # shellcheck disable=SC2043
    for hook in ${hookInvocations}; do
      echo "▸ pre-rebuild hook: $hook"
      if ! "$hook"; then
        echo "✗ rebuild aborted: hook failed ($hook)" >&2
        exit 1
      fi
    done
  '';

  # `deploy_host <hostname> [nixos-rebuild args...]` — the single definition of
  # what deploying one host means, sourced by both `rebuild` and `rebuild-all`.
  #
  # Shared rather than duplicated because duplicated flake invocations drift:
  # `nixflash` carried the same `github:` ref as `rebuild` but missed its
  # `--refresh`, and could flash an ISO built from the previous HEAD while
  # printing a perfectly normal success line. One definition, one place to fix.
  #
  # --refresh forces nix to re-fetch the flake source (bypasses the 1-hour
  # tarball cache) so a `git push` immediately followed by a deploy uses the
  # just-pushed commit.
  #
  # Remote deploys go over SSH via --target-host (no rsync). `--sudo` is
  # non-interactive because server-class hosts run passwordless wheel; see
  # users/server-admin/account.nix.
  deployHost = ''
    deploy_host() {
      local target="$1"; shift
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
    }
  '';

  # Warns when the local repo differs from what `rebuild` actually deploys
  # (origin/master). There are two independent ways to diverge — a dirty
  # working tree and unpushed commits — and only the second used to be
  # checked. So editing a file and running `rebuild` deployed the cloud
  # version silently, with a fresh store path and a convincing "Done."
  #
  # Doesn't block: you may knowingly redeploy the cloud version while
  # carrying unrelated local dev config. It just can't be missed anymore.
  #
  # `sed -n '1,10p'` rather than `head -10` on purpose: head closes the pipe
  # early, which under `set -o pipefail` surfaces as SIGPIPE (141) and trips
  # errexit. sed drains stdin, so the pipeline always exits 0.
  warnIfLocalDiverged = ''
    if [[ -d "$HOME/NixOS/.git" ]]; then
      diverged=0

      dirty=$(git -C "$HOME/NixOS" status --porcelain 2>/dev/null || true)
      if [[ -n "$dirty" ]]; then
        diverged=1
        echo "⚠ ~/NixOS has uncommitted changes:" >&2
        echo "$dirty" | sed -n '1,10{s/^/      /;p;}' >&2
        extra=$(( $(echo "$dirty" | wc -l) - 10 ))
        if [[ "$extra" -gt 0 ]]; then
          echo "      … and $extra more" >&2
        fi
      fi

      ahead=$(git -C "$HOME/NixOS" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
      if [[ "$ahead" -gt 0 ]]; then
        diverged=1
        echo "⚠ ~/NixOS has $ahead unpushed commit(s)." >&2
      fi

      if [[ "$diverged" -eq 1 ]]; then
        echo "  → rebuild deploys ${cloudFlake} — the above is NOT included." >&2
        echo "    Use \`trebuild\` to deploy locally, or commit and push first." >&2
      fi
    fi
  '';
}

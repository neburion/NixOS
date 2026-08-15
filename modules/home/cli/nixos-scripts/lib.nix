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

  # Warns if the local repo has commits ahead of origin/master. Doesn't
  # block — you might have uncommitted-but-intentional dev config that
  # you meant to deploy via trebuild. Just makes it visible.
  warnIfLocalAhead = ''
    if [[ -d "$HOME/NixOS/.git" ]]; then
      ahead=$(git -C "$HOME/NixOS" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
      if [[ "$ahead" -gt 0 ]]; then
        echo "⚠ Local ~/NixOS is $ahead commit(s) ahead of origin — rebuild deploys the CLOUD version" >&2
        echo "  (use \`trebuild\` if you want your local uncommitted changes deployed)" >&2
      fi
    fi
  '';
}

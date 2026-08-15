{ pkgs, osConfig, ... }:

# Portable bash entry points for the fleet rebuild workflow.
#
# ┌──────────┬─────────────────────────────────────────┬───────────────────────────┐
# │ Command  │ Flake source                            │ Semantics                 │
# ├──────────┼─────────────────────────────────────────┼───────────────────────────┤
# │ rebuild  │ github:neburion/NixOS (cloud, always    │ "make this host match     │
# │          │ latest master, --refresh forces         │  master right now"        │
# │          │ re-fetch)                               │                           │
# │ trebuild │ path:$HOME/NixOS (local checkout)       │ "try my uncommitted       │
# │          │                                         │  changes with `test`      │
# │          │                                         │  activation — no reboot   │
# │          │                                         │  persistence"             │
# │ update   │ path:$HOME/NixOS                        │ "bump flake.lock inputs,  │
# │          │                                         │  rebuild locally to       │
# │          │                                         │  validate. Commit + push  │
# │          │                                         │  the new lock afterward." │
# └──────────┴─────────────────────────────────────────┴───────────────────────────┘
#
# WHY the split: `rebuild` always deploying from the cloud means no host is
# "the source of truth" for what's deployed — pod042 can die and any other
# fleet member with the flake URL + sops key + SSH access can rebuild
# anything from master. Editing happens on whatever host has a local
# checkout; deploying happens against the pushed cloud state.
#
# Discipline this enforces: `rebuild` after edits requires you to `git push`
# first. If local has commits not pushed to origin/master, `rebuild` warns
# but proceeds — the deploy will use whatever's on origin/master (i.e. NOT
# your uncommitted work).
#
# Pre-rebuild hooks (config.rebuild.preHooks — cf-reconcile, future r2
# reconcilers, etc.) run before every rebuild/trebuild. Non-zero exit
# aborts before any host is touched. See modules/system/rebuild-hooks/
# registry.nix.

let
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

  rebuild = pkgs.writeShellApplication {
    name = "rebuild";
    runtimeInputs = with pkgs; [ nixos-rebuild nettools openssh git ];
    text = ''
      # Prime sudo BEFORE running hooks — hooks (e.g. cf-reconcile) shell out
      # to `sudo sops --decrypt` for reading the age key, and need the cached
      # credential. Requires `Defaults !tty_tickets` in sudo config so the
      # cache survives the subshell (see modules/system/security/sudo.nix).
      sudo -Sv

      ${warnIfLocalAhead}
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
  };

  trebuild = pkgs.writeShellApplication {
    name = "trebuild";
    runtimeInputs = with pkgs; [ nixos-rebuild nettools openssh ];
    text = ''
      sudo -Sv

      ${runHooks}

      target=""
      if [[ $# -gt 0 && "$1" != -* && "$1" != "--" ]]; then
        target="$1"
        shift
      fi
      [[ "''${1:-}" == "--" ]] && shift

      if [[ -z "$target" ]]; then
        target="$(hostname -s)"
      fi

      if [[ "$target" != "$(hostname -s)" ]]; then
        echo "▸ remote test → $target (from path:$HOME/NixOS — local, uncommitted OK)"
        nixos-rebuild test \
          --flake "path:$HOME/NixOS#$target" \
          --target-host "$target" \
          --sudo \
          --no-reexec \
          "$@"
      else
        echo "▸ local test → $target (from path:$HOME/NixOS — local, uncommitted OK)"
        sudo nixos-rebuild test \
          --flake "path:$HOME/NixOS#$target" \
          "$@"
      fi
    '';
  };

  update = pkgs.writeShellApplication {
    name = "update";
    runtimeInputs = with pkgs; [ nix nixos-rebuild nettools ];
    text = ''
      sudo -Sv
      # Local operation: bumps flake.lock in the checkout. You commit +
      # push the new lock, then `rebuild` on any host picks it up from
      # the cloud. This wrapper also does a local `test` rebuild so you
      # can verify the update doesn't break anything before pushing.
      sudo nix flake update --flake "$HOME/NixOS"
      echo "▸ flake.lock updated. Testing locally before you commit + push..."
      sudo nixos-rebuild test --flake "path:$HOME/NixOS#$(hostname -s)" "$@"
      echo ""
      echo "▸ If test looks good: git -C ~/NixOS add flake.lock && git commit + push"
    '';
  };
in
{
  home.packages = [ rebuild trebuild update ];
}

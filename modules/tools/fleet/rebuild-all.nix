{ pkgs, osConfig, ... }:

# `rebuild-all` — switch EVERY fleet host to whatever is on origin/master.
#
# Same semantics as `rebuild` applied to the whole fleet, with three
# differences that only matter when there's more than one target:
#
#   1. Hooks and the sudo prime run ONCE, not per host. cf-reconcile already
#      reconciles every host's tunnels in a single pass, so running it per
#      host would just re-hit the Cloudflare API N times for the same result.
#   2. A failing host does not abort the run. Aborting halfway would leave the
#      fleet in a split state with no summary of which half landed, which is
#      the opposite of what "all" should mean. Failures are collected and
#      reported, and the script exits non-zero if any occurred.
#   3. The local host is deployed LAST — see the ordering comment below.
#
# Extra args are passed through to every nixos-rebuild invocation, so
# `rebuild-all --show-trace` works.

let
  inherit (import ./lib.nix { inherit osConfig; })
    cloudFlake runHooks warnIfLocalDiverged deployHost;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "rebuild-all";
      runtimeInputs = with pkgs; [
        nixos-rebuild nettools openssh git coreutils gnused nix jq
      ];
      text = ''
        # Prime sudo BEFORE hooks, same reasoning as `rebuild`: hooks shell out
        # to `sudo sops --decrypt` and need the cached credential.
        sudo -Sv

        ${warnIfLocalDiverged}
        ${runHooks}
        ${deployHost}

        self="$(hostname -s)"

        # Host list comes from the CLOUD flake, not the local checkout. This
        # command deploys origin/master, so a host that exists only locally
        # isn't deployable anyway and has no business appearing in the plan.
        mapfile -t all_hosts < <(nix eval --refresh --json \
          "${cloudFlake}#nixosConfigurations" --apply builtins.attrNames \
          | jq -r '.[]')

        # `installer` lives under a host directory like any other but builds an
        # isoImage, not a switchable toplevel — same exclusion cf-reconcile makes.
        targets=()
        for h in "''${all_hosts[@]}"; do
          [[ "$h" == "installer" ]] && continue
          [[ "$h" == "$self" ]] && continue
          targets+=("$h")
        done

        # Local host last. A local `switch` can restart networking or swap the
        # running shell's environment out from under this very script; doing it
        # first would risk killing the run before the remotes are touched.
        targets+=("$self")

        echo "▸ fleet deploy plan: ''${targets[*]}"
        echo

        ok=()
        failed=()
        skipped=()

        for host in "''${targets[@]}"; do
          if [[ "$host" != "$self" ]]; then
            # Probe first so a powered-off laptop costs 5 seconds instead of
            # hanging on SSH's default connect timeout. Unreachable is reported
            # separately from failed — "it was off" and "it broke" are
            # different problems and shouldn't look alike in the summary.
            if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$host" true 2>/dev/null; then
              echo "⚠ $host unreachable — skipping"
              skipped+=("$host")
              echo
              continue
            fi
          fi

          if deploy_host "$host" "$@"; then
            ok+=("$host")
          else
            echo "✗ $host failed" >&2
            failed+=("$host")
          fi
          echo
        done

        echo "──────── fleet summary ────────"
        if (( ''${#ok[@]} > 0 )); then
          echo "  ✓ deployed:    ''${ok[*]}"
        fi
        if (( ''${#skipped[@]} > 0 )); then
          echo "  ⚠ unreachable: ''${skipped[*]}"
        fi
        if (( ''${#failed[@]} > 0 )); then
          echo "  ✗ failed:      ''${failed[*]}"
        fi

        # Exit non-zero if anything didn't land, so this composes in scripts
        # and doesn't report success for a partial fleet. Note `Done.` is not
        # proof — check the summary above, not just the exit code.
        (( ''${#failed[@]} == 0 ))
      '';
    })
  ];
}

{ pkgs, osConfig, ... }:

# Portable bash entry points for the common NixOS rebuild workflow.
# Formerly fish aliases in cli/shell/fish.nix — moved out so they work
# from any shell (bash, zsh, sh -c, cron, systemd units, etc.).
#
# `rebuild` handles two modes:
#   - `rebuild [nix-args...]`
#       Local host, `nixos-rebuild switch` on the current machine.
#   - `rebuild <hostname> [nix-args...]`
#       Remote deploy via nixos-rebuild --target-host over SSH. Builds
#       locally, ships store paths over SSH (no rsync), activates on
#       the remote. `--use-remote-sudo` handles the target's sudo.
#
# Before invoking nixos-rebuild, the wrapper iterates every hook
# registered under `config.rebuild.preHooks` in name-sorted order.
# Non-zero exit from any hook aborts before touching the host.
# See modules/system/rebuild-hooks/registry.nix for the pattern.

let
  # Space-separated list of hook script store paths. Each hook is a
  # writeShellApplication package; its main binary is at
  # ${hook}/bin/${hook.pname or hook.name}. We resolve at build time so
  # the runtime loop is a simple `for`.
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

  # `sudo -Sv` reads the password once (from stdin if piped, from the
  # terminal otherwise), primes the timestamp cache, then the actual
  # nixos-rebuild sudo call reuses it without re-prompting. Makes the
  # script usable both interactively (fish prompts you once) and from
  # non-tty contexts (Claude Code Bash tool: `echo <pw> | rebuild`).
  rebuild = pkgs.writeShellApplication {
    name = "rebuild";
    runtimeInputs = with pkgs; [ nixos-rebuild nettools openssh ];
    text = ''
      # Prime sudo BEFORE running hooks — hooks (e.g. cf-reconcile) shell out
      # to `sudo sops --decrypt` for reading the age key, and need the cached
      # credential. Requires `Defaults !tty_tickets` in sudo config so the
      # cache survives the subshell (see modules/system/security/sudo.nix).
      sudo -Sv

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

      if [[ -n "$target" && "$target" != "$(hostname -s)" ]]; then
        echo "▸ remote deploy → $target"
        nixos-rebuild switch \
          --flake "path:$HOME/NixOS#$target" \
          --target-host "$target" \
          --sudo \
          --no-reexec \
          "$@"
      else
        sudo nixos-rebuild switch \
          --flake "path:$HOME/NixOS#$(hostname -s)" \
          "$@"
      fi
    '';
  };

  trebuild = pkgs.writeShellApplication {
    name = "trebuild";
    runtimeInputs = with pkgs; [ nixos-rebuild nettools openssh ];
    text = ''
      ${runHooks}

      target=""
      if [[ $# -gt 0 && "$1" != -* && "$1" != "--" ]]; then
        target="$1"
        shift
      fi
      [[ "''${1:-}" == "--" ]] && shift

      if [[ -n "$target" && "$target" != "$(hostname -s)" ]]; then
        nixos-rebuild test \
          --flake "path:$HOME/NixOS#$target" \
          --target-host "$target" \
          --sudo \
          --no-reexec \
          "$@"
      else
        sudo -Sv
        sudo nixos-rebuild test \
          --flake "path:$HOME/NixOS#$(hostname -s)" \
          "$@"
      fi
    '';
  };

  update = pkgs.writeShellApplication {
    name = "update";
    runtimeInputs = with pkgs; [ nix nixos-rebuild nettools ];
    text = ''
      sudo -Sv
      sudo nix flake update --flake "$HOME/NixOS"
      sudo nixos-rebuild switch --flake "path:$HOME/NixOS#$(hostname -s)" "$@"
    '';
  };
in
{
  home.packages = [ rebuild trebuild update ];
}

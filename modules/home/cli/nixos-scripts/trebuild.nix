{ pkgs, osConfig, ... }:

# `trebuild [host]` — `nixos-rebuild test` from the LOCAL checkout, so
# uncommitted edits can be tried without pushing. No boot persistence.

let
  inherit (import ./lib.nix { inherit osConfig; }) runHooks;
in
{
  home.packages = [
    (pkgs.writeShellApplication {
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
    })
  ];
}

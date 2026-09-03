{ pkgs, lib, config, ... }:

# theme-set: single publisher of theme changes.
#
# Writes the new name to ~/.local/state/quickshell/active-theme (source of
# truth watched by QS ThemeState) then invokes every registered hook with
# baked /nix/store paths — no `.config/theme-hooks.d/` runtime scan.
#
# Each consumer module contributes its own reaction via `themeHooks.<name>`
# (see ./registry.nix).

let
  hookInvocations = lib.concatMapStringsSep "\n    "
    (h: ''"${h}" "$theme"'')
    (lib.attrValues config.themeHooks);
in
{
  imports = [ ./registry.nix ];

  home.packages = [
    (pkgs.writeShellApplication {
      name = "theme-set";
      runtimeInputs = with pkgs; [ coreutils ];
      text = ''
        theme="''${1:-}"
        if [ -z "$theme" ]; then
          echo "usage: theme-set <name>" >&2
          exit 2
        fi
        mkdir -p "$HOME/.local/state/quickshell"
        printf '%s\n' "$theme" > "$HOME/.local/state/quickshell/active-theme"
        ${hookInvocations}
      '';
    })
  ];
}

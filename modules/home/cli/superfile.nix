{ pkgs, lib, themes, ... }:

let
  superfileThemeMap = lib.mapAttrs (_: t: t.superfileTheme or "hacks") themes;

  caseLines = lib.concatStringsSep "\n        " (lib.mapAttrsToList (n: spf:
    ''${n}) spf_theme="${spf}" ;;''
  ) superfileThemeMap);
in
{
  programs.superfile = {
    enable = true;
    settings = {
      editor = "nvim";
      dir_editor = "nvim";
      ignore_missing_fields = true;
      theme = "active";
    };
  };

  # Point ~/.config/superfile/theme/active.toml at the palette matching the
  # current hypr theme. Superfile extracts its built-in themes to this dir on
  # first launch, so the symlink target is created lazily — the activation
  # silently no-ops if the file isn't there yet.
  home.activation.syncSuperfileTheme = lib.hm.dag.entryAfter [ "writeBoundary" "initHyprTheme" ] ''
    HYPR_THEME="$HOME/.config/hypr/theme.conf"
    SPF_THEMES="$HOME/.config/superfile/theme"
    if [ -L "$HYPR_THEME" ] && [ -d "$SPF_THEMES" ]; then
      name=$(basename "$(readlink "$HYPR_THEME")" .conf)
      spf_theme="hacks"
      case "$name" in
        ${caseLines}
        *) ;;
      esac
      if [ -f "$SPF_THEMES/$spf_theme.toml" ]; then
        ln -sf "$SPF_THEMES/$spf_theme.toml" "$SPF_THEMES/active.toml"
      fi
    fi
  '';

  themeHooks.superfile = pkgs.writeShellScript "theme-hook-superfile" ''
    theme="$1"
    SPF_THEMES="$HOME/.config/superfile/theme"
    spf_theme="hacks"
    case "$theme" in
      ${caseLines}
      *) ;;
    esac
    if [ -f "$SPF_THEMES/$spf_theme.toml" ]; then
      ln -sf "$SPF_THEMES/$spf_theme.toml" "$SPF_THEMES/active.toml"
    fi
  '';
}

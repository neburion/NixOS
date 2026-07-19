{ pkgs, lib, themes, ... }:

let
  zedThemeMap = lib.mapAttrs (_: t: t.zedTheme or "One Dark") themes;
  caseLines = lib.concatStringsSep "\n      " (lib.mapAttrsToList (n: z:
    ''${n}) zed_theme="${z}" ;;''
  ) zedThemeMap);
in
{
  programs.zed-editor = {
    enable = true;
    extensions = [
      "nix"
      "toml"
      "zig"
      "odin"
      "nord"
      "everforest"
      "catppuccin"
    ];
    extraPackages = with pkgs; [
      clang-tools  # clangd for C/C++
      rust-analyzer
      zls
      ols
      nil          # nix LSP
      pyright
    ];
    userSettings = {
      ui_font_size = 16;
      buffer_font_size = 14;
      theme = {
        mode = "dark";
        dark = "One Dark";
      };
      vim_mode = true;
      autosave = "on_focus_change";
      format_on_save = "on";
      terminal = {
        shell = {
          program = "fish";
        };
      };
    };
  };

  themeHooks.zed = pkgs.writeShellScript "theme-hook-zed" ''
    theme="$1"
    zed_theme="One Dark"
    case "$theme" in
      ${caseLines}
      *) ;;
    esac
    zed_settings="$HOME/.config/zed/settings.json"
    if [ -f "$zed_settings" ]; then
      tmp=$(${pkgs.coreutils}/bin/mktemp)
      ${pkgs.jq}/bin/jq --arg t "$zed_theme" \
        '.theme.dark = $t | .theme.mode = "dark"' \
        "$zed_settings" > "$tmp" && ${pkgs.coreutils}/bin/mv "$tmp" "$zed_settings"
    fi
  '';
}

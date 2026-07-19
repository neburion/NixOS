{ pkgs, lib, themes, ... }:
let
  strip = lib.removePrefix "#";

  # Build a spicetify color.ini with one section per palette — all derived from
  # the existing bg/surface/selection/fg/fishPrimary/fishSecondary palette fields.
  colorIniContent = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: t: ''
    [${name}]
    text               = ${strip t.fg}
    subtext            = ${strip (t.fishSecondary or t.fg)}
    sidebar-text       = ${strip t.fg}
    main               = ${strip t.bg}
    sidebar            = ${strip t.bg}
    player             = ${strip t.bg}
    system             = ${strip t.bg}
    nav                = ${strip t.selection}
    highlight          = ${strip t.surface}
    highlight-elevated = ${strip t.selection}
    header             = ${strip t.bg}
    button             = ${strip (t.fishPrimary or t.fg)}
    button-active      = ${strip (t.fishPrimary or t.fg)}
    button-disabled    = ${strip t.selection}
    tab-active         = ${strip t.selection}
    notification       = ${strip (t.fishPrimary or t.fg)}
    notification-error = f38ba8
    misc               = ${strip (t.fishPrimary or t.fg)}
  '') themes);

  # Theme src: spicetify builder does `cp -r src Themes/$name`, so the files
  # must live at the root of the derivation, not in a named subdirectory.
  themeDir = pkgs.runCommand "spicetify-nix-palettes" {} ''
    mkdir -p "$out"
    cp ${pkgs.writeText "color.ini" colorIniContent} "$out/color.ini"
    touch "$out/user.css"
  '';
in
{
  programs.spicetify = {
    enable = true;
    theme = {
      name = "NixPalettes";
      src = themeDir;
      requiredExtensions = [];
    };
    colorScheme = "dark";
  };

  themeHooks.spotify = pkgs.writeShellScript "theme-hook-spotify" ''
    theme="$1"
    if command -v spicetify >/dev/null 2>&1; then
      spicetify config colorscheme "$theme" >/dev/null 2>&1 || true
      spicetify apply >/dev/null 2>&1 || true
    fi
  '';
}

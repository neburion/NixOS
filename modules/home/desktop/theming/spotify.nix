{ pkgs, lib, themes, ... }:

# Spotify colours for the palette-driven presets (clean, simple).
#
# One color.ini section per entry in `themes`, all derived from the shared
# bg/surface/selection/fg/fishPrimary/fishSecondary fields, so adding a palette
# to modules/home/themes/ adds a Spotify scheme with it.
#
# It does not follow `theme-set`, and cannot. spicetify resolves colorScheme at
# build time and writes the chosen section into Apps/xpui/colors.css inside the
# spiced Spotify derivation; that path is read-only, and the spicetify CLI that
# would rewrite it is not installed. The scheme below is therefore a build-time
# pick — change it and rebuild. The other sections still ship in the theme dir,
# which is what makes that a one-line change rather than a rewrite.
#
# (There used to be a `themeHooks.spotify` here that shelled out to
# `spicetify config colorscheme && spicetify apply`. Both calls were guarded by
# `command -v spicetify`, which has never succeeded, so every theme switch since
# it was written silently did nothing. Removed rather than left to look load-
# bearing.)

let
  strip = lib.removePrefix "#";

  colorIniContent = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: t: ''
    [${name}]
    text               = ${strip t.fg}
    subtext            = ${strip (t.fishSecondary or t.fg)}
    sidebar-text       = ${strip t.fg}
    main               = ${strip t.bg}
    sidebar            = ${strip t.bg}
    player             = ${strip t.bg}
    system             = ${strip t.bg}
    card               = ${strip t.surface}
    shadow             = 000000
    selected-row       = ${strip (t.fishPrimary or t.fg)}
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

  # The spicetify builder does `cp -r src Themes/$name`, so the files must sit
  # at the root of the derivation, not in a named subdirectory.
  themeDir = pkgs.runCommand "spicetify-nix-palettes" {} ''
    mkdir -p "$out"
    cp ${pkgs.writeText "color.ini" colorIniContent} "$out/color.ini"
    touch "$out/user.css"
  '';
in
{
  programs.spicetify = {
    theme = {
      name = "NixPalettes";
      src = themeDir;
      requiredExtensions = [];
    };
    colorScheme = "dark";
  };
}

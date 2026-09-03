{ pkgs, ... }:

# BreezeX Black — ful1e5's extended Breeze set. Narrow arrow with a clean
# taper, black fill, white outline, and the colour confined to badges (red for
# no-drop, blue for help) rather than smeared across whole shapes the way
# Borealis puts a green aperture on busy.
#
# Not in nixpkgs — only the rose-pine tinted BreezeX variants are, and a rose
# tint on a deliberately achromatic desktop is the wrong compromise. So this
# packages the upstream release directly, and that has a cost worth stating:
# the URL and hash below are pinned by hand, so a new upstream version needs a
# manual bump, where a theme taken straight from nixpkgs updates for free.
# Cursor themes move roughly yearly, so the trade is cheap — but it is a trade.
# If the pin ever rots, pkgs.borealis-cursors is the zero-maintenance fallback;
# it used to sit beside this file as borealis.nix, unimported by any preset,
# and is in git history if the old module is wanted verbatim.
#
# Size 24 — the X default. The repo carried 15 from before cursors had their
# own module, which is why several earlier themes read as undersized whatever
# their drawing.

let
  name = "BreezeX-Black";
  size = 24;

  breezex-black = pkgs.stdenvNoCC.mkDerivation {
    pname = "breezex-black-cursors";
    version = "2.0.1";

    src = pkgs.fetchurl {
      url = "https://github.com/ful1e5/BreezeX_Cursor/releases/download/v2.0.1/BreezeX-Black.tar.xz";
      hash = "sha256-dzt1UjdIFzQJ7mIoQbD3Sx6AYXpcWz3LtTp6w9BswjM=";
    };

    # The tarball carries a single BreezeX-Black/ directory holding index.theme
    # and cursors/, which is already the shape an icon theme wants — so this is
    # a copy, not a build.
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/icons"
      cp -r . "$out/share/icons/${name}"
      runHook postInstall
    '';

    meta = {
      description = "BreezeX Black XCursor theme";
      homepage = "https://github.com/ful1e5/BreezeX_Cursor";
      license = pkgs.lib.licenses.gpl3Only;
      platforms = pkgs.lib.platforms.linux;
    };
  };
in
{
  home.pointerCursor = {
    package = breezex-black;
    inherit name size;
    gtk.enable = true;
    x11.enable = true;
  };

  wayland.windowManager.hyprland.settings = {
    "$cursorTheme" = name;
    "$cursorSize"  = toString size;
  };
}

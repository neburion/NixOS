{ ... }:

# GTK for the glass preset. Pinned, not synced.
#
# clean's gtk/ carries five per-theme GTK packages plus theme-sync.nix, which
# registers a themeHook and rewrites gtk.css on every theme change. With one
# palette none of that applies, so this has only the pieces about looking right
# rather than about switching: the icon theme, the font, and a single dark GTK
# theme.
#
# The three shared files used to be imported straight out of the other preset's
# directory. They are copied now — nothing crosses out of desktop/<preset>/,
# in either direction.

{
  imports = [
    ./adwaita-icon-theme.nix
    ./gnome-themes-extra.nix
    ./glib.nix
    ./config.nix
    ./dconf.nix
  ];
}

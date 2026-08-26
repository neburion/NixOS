{ ... }:

# GTK for the glass preset. Pinned, not synced.
#
# theming/gtk/ imports five per-theme GTK packages plus theme-sync.nix, which
# registers a themeHook and rewrites gtk.css on every theme change. With one
# palette none of that applies, so this imports only the pieces that are about
# looking right rather than about switching: the icon theme, the font, and a
# single dark GTK theme.

{
  imports = [
    ../gtk/adwaita-icon-theme.nix
    ../gtk/gnome-themes-extra.nix
    ../gtk/glib.nix
    ./config.nix
    ./dconf.nix
  ];
}

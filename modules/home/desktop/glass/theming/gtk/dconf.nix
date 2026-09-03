{ ... }:

# Pinned dark, and pinned to the one GTK theme. The clean preset lets
# theme-set drive gtk-theme at runtime; here it is settled at build time.

{
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme    = "Adwaita-dark";
      font-name    = "Inter 11";
    };
  };
}

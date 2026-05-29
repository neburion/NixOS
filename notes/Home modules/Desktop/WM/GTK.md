# GTK

`home-modules/desktop/wm/gtk/`. GTK 3/4 theming.

```
gtk/
├── default.nix      packages, dconf, activation script, gtk.* options
└── css.nix          generates per-palette gtk3 + gtk4 CSS strings
```

## Installed
- `glib`, `gnome-themes-extra`, `adwaita-icon-theme`
- Theme packages: `catppuccin-gtk` (mocha + blue accent), `gruvbox-dark-gtk`, `nordic`, `everforest-gtk-theme`

## Custom hybrid icon theme

`hybrid-icons` derivation creates `Adwaita-Hybrid` icon theme that inherits in order: Adwaita → Papirus-Dark → hicolor.

Rationale: Adwaita has the cleanest file/folder icons (good for Nautilus), but lacks tray applet icons; Papirus-Dark fills those in.

Set as the user's icon theme via `gtk.iconTheme`.

## Theme application

```nix
gtk = {
  enable = true;
  iconTheme = { name = "Adwaita-Hybrid"; package = hybrid-icons; };
  font = { name = "FiraMono Nerd Font"; size = 11; };
  gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
  gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
};

dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
```

## Runtime theme-sync activation

`home.activation.syncGtkTheme` (after writeBoundary + initHyprTheme):

1. Reads `~/.config/hypr/theme.conf` (symlink whose basename = active palette name)
2. Looks up the matching GTK theme name, GTK3 CSS path, GTK4 CSS path via baked-in case statements (generated from `css.nix`)
3. Calls `gsettings set org.gnome.desktop.interface gtk-theme "$theme"`
4. `install -D -m 644` the GTK3 and GTK4 CSS files into `~/.config/gtk-{3,4}.0/gtk.css`

Note about `install -D -m 644`: needed because previous activations leave the file as `-r--r--r--` (sourced from /nix/store), so plain `cp` would fail with EACCES.

## What `css.nix` does

Generates per-palette CSS files for Nautilus (libadwaita window/accent colors) and nm-applet (selection color fix). Exposes `gtk3Files` and `gtk4Files` attrsets to consumers (theme-switcher and gtk's activation script).

## See also

- [[Concepts/Theme switching]] — runtime switcher also uses css.nix paths
- [[Modules/Desktop/Integrations]] — `programs.dconf` system enable (required for gsettings to work)

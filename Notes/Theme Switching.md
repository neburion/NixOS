Triggered with `SUPER + SHIFT + Space`. Opens a wofi dmenu listing available themes. Selecting one applies the theme live to wofi, waybar, mako, and GTK.

## How it works

Themes are defined as Nix attribute sets in `home-modules/themes/`:
- Each file (e.g. `catppuccin.nix`) exports `{ bg, surface, selection, fg }` color values
- `default.nix` collects all themes into a single attrset

At build time, home-manager generates CSS/config files for each theme and places them in:
- `~/.config/wofi/themes/<name>.css`
- `~/.config/waybar/themes/<name>.css`
- `~/.config/mako/themes/<name>`

These are **read-only symlinks into the nix store** — the theme switcher script never modifies them.

The script (`wofi-theme-switcher`) switches themes at runtime by:
1. Updating `~/.config/wofi/themes/active.css` symlink
2. Updating `~/.config/waybar/themes/active.css` symlink
3. Copying the chosen mako theme over `~/.config/mako/config`
4. Running `gsettings` to change the GTK theme
5. Restarting waybar, reloading mako

Wofi and waybar CSS both `@import` their respective `active.css`, so they pick up the change on next launch / restart.

## Available themes

| Name       | GTK theme                        |
|------------|----------------------------------|
| dark       | Adwaita-dark (default)           |
| catppuccin | catppuccin-mocha-blue-standard   |
| gruvbox    | gruvbox-dark                     |
| nord       | Nordic-darker                    |
| everforest | Everforest-Dark-B                |

## Key files

| File | Purpose |
|------|---------|
| `home-modules/themes/default.nix` | Aggregates all theme color sets |
| `home-modules/themes/<name>.nix` | Color values for each theme |
| `home-modules/desktop/wm/wofi/scripts/wofi-theme-switcher.nix` | The switcher script |
| `home-modules/desktop/wm/wofi/default.nix` | Generates wofi CSS files per theme |
| `home-modules/desktop/wm/waybar/default.nix` | Generates waybar CSS files per theme |
| `home-modules/desktop/wm/mako/default.nix` | Generates mako config files per theme |
| `home-modules/desktop/wm/gtk.nix` | GTK theme packages and default |

## Persistence across rebuilds

The theme is persisted via the `~/.config/hypr/theme.conf` symlink (pointing into `~/.config/hypr/themes/`). The wofi-theme-switcher updates this symlink at runtime; on the next `home-manager switch`, the `syncGtkTheme` activation script in `gtk.nix` reads it back and re-applies the matching GTK theme, GTK4 CSS, and GTK3 CSS. The hypr symlink is the single source of truth for the active theme.

## Nautilus

Libadwaita apps (Nautilus, Loupe, etc.) read `~/.config/gtk-4.0/gtk.css` once at startup and do not live-reload it. The theme switcher therefore runs `nautilus --quit` after writing the new CSS so the next `$mod+F` launch picks up the fresh palette.

## Notes
- The GTK CSS files for each theme are baked into the nix store via `gtk-css.nix` and consumed by both the activation script and the runtime switcher (so the two code paths can't drift).

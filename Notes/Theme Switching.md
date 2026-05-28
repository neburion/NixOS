Triggered with `SUPER + SHIFT + Space`. Opens a wofi dmenu listing available themes. Selecting one applies the theme live to wofi, waybar, mako, GTK, ghostty, fish, swww/waypaper, and superfile.

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
6. Symlinking `~/.config/superfile/theme/active.toml` to the mapped palette (new superfile sessions pick up the theme — running TUIs don't reload)

Wofi and waybar CSS both `@import` their respective `active.css`, so they pick up the change on next launch / restart.

## Available themes

| Name       | GTK theme                        | Superfile theme         |
|------------|----------------------------------|-------------------------|
| dark       | Adwaita-dark (default)           | hacks                   |
| catppuccin | catppuccin-mocha-blue-standard   | catppuccin              |
| gruvbox    | gruvbox-dark                     | gruvbox-dark-hard       |
| nord       | Nordic-darker                    | nord                    |
| everforest | Everforest-Dark-B                | everforest-dark-medium  |

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
| `home-modules/cli/superfile.nix` | Sets `theme = "active"` and the activation that syncs `active.toml` |

## Persistence across rebuilds

The theme is persisted via the `~/.config/hypr/theme.conf` symlink (pointing into `~/.config/hypr/themes/`). The wofi-theme-switcher updates this symlink at runtime; on the next `home-manager switch`, the `syncGtkTheme` activation in `gtk.nix` and `syncSuperfileTheme` activation in `superfile.nix` read it back and re-apply the matching GTK theme, GTK4/3 CSS, and superfile `active.toml` symlink. The hypr symlink is the single source of truth for the active theme.

## Nautilus

Libadwaita apps (Nautilus, Loupe, etc.) read `~/.config/gtk-4.0/gtk.css` once at startup and do not live-reload it. Nautilus is also a `GApplication` that stays running in the background after the window is closed, so manually close+reopen reuses the same cached style provider and shows the old theme. The switcher therefore calls `nautilus --quit` to fully terminate the process; the next `$mod+F` launch picks up the new palette. Nautilus's DBus interface doesn't expose the current window location, so the path can't be preserved across the restart.

## Notes
- The GTK CSS files for each theme are baked into the nix store via `gtk-css.nix` and consumed by both the activation script and the runtime switcher (so the two code paths can't drift).

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

## Known bugs

### 1. Mako dual service conflict
**Files:** `mako/config.nix` + `mako/default.nix`

`config.nix` enables `services.mako` (home-manager's built-in mako module, which creates its own systemd service). `default.nix` also defines `systemd.user.services.mako` manually. Two units trying to manage the same daemon will conflict — one will fail to start.

**Fix:** Remove the custom `systemd.user.services.mako` block from `mako/default.nix`, since `services.mako.enable = true` already handles it.

### 2. Stray `xdg.configFile."mako/config".force = true`
**File:** `mako/config.nix` line 33

This sets `.force = true` on the mako config path without providing any `text` or `source`. The `services.mako` module writes to this same path internally. This orphaned attribute may cause a home-manager evaluation conflict or silently override the managed config.

**Fix:** Remove the standalone `xdg.configFile."mako/config".force = true` line — it conflicts with `services.mako`'s own file management.

### 3. Waybar doesn't restart if it wasn't running
**File:** `wofi-theme-switcher.nix` line 40

```bash
pkill waybar && waybar &
```

`&&` means waybar only relaunches if `pkill` succeeds. If waybar isn't currently running, `pkill` exits non-zero and waybar never starts.

**Fix:** Use `;` instead of `&&`:
```bash
pkill waybar; waybar &
```

### 4. GTK theme reverts on rebuild
**File:** `gtk.nix` line 30

The `gtk.theme.name` is hardcoded to `"Adwaita-dark"`. The theme switcher changes the GTK theme at runtime via `gsettings`, but `home-manager switch` rewrites the GTK config and resets it back to `Adwaita-dark`.

**Fix:** The GTK theme needs to be driven by a mutable value (e.g. a file read at activation time) or accepted as a limitation — GTK theme changes survive until the next rebuild.

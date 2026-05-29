# Theme switching

The most cross-cutting feature in the config. Switching themes at runtime updates: wofi, waybar, mako, hyprland, ghostty, superfile, GTK 3/4, fish prompt, Nautilus styling, wallpaper, and SDDM background — without rebuilding.

## Trigger

`SUPER+SHIFT+Space` runs `wofi-theme-switcher` (see [[Home modules/Desktop/WM/Wofi]]).

## Storage model

For every theme-aware tool there's a `themes/` dir under its config holding a generated file PER palette:

```
~/.config/wofi/themes/{catppuccin,dark,everforest,gruvbox,nord}.css
~/.config/waybar/themes/{...}.css
~/.config/mako/themes/{...}
~/.config/hypr/themes/{...}.conf
~/.config/ghostty/themes/{...}.conf
~/.config/superfile/theme/{onedark,...}.toml      ← superfile names differ
```

These files are nix-store-built — see each module's `xdg.configFile = lib.mapAttrs' …` block ([[Home modules/Themes]] consumers).

The ACTIVE palette is selected by a symlink (or file) one level up:

| Tool | Active selector |
|---|---|
| wofi | `themes/active.css` → `<chosen>.css` |
| waybar | `themes/active.css` → `<chosen>.css` |
| mako | `~/.config/mako/config` ← copied from `themes/<chosen>` (no @import support) |
| hyprland | `~/.config/hypr/theme.conf` → `themes/<chosen>.conf` |
| ghostty | `themes/active.conf` ← `echo "theme = <chosen>"` |
| superfile | `theme/active.toml` → `theme/<superfile-mapped-name>.toml` |

The tools' main config files reference the active file (CSS `@import`, hyprland `source =`, ghostty `config-file =`, etc.). Switching = changing the symlink target.

## What `wofi-theme-switcher` actually does

(file: `home-modules/desktop/wm/wofi/scripts/wofi-theme-switcher.nix`)

1. Initialize any missing `active.*` symlinks/files (pointing at `dark` defaults)
2. Dmenu — list every `.css` in `wofi/themes/` (minus `active.css`)
3. Update `wofi/themes/active.css` symlink
4. Update `waybar/themes/active.css` symlink
5. Replace `~/.config/mako/config` with `themes/<chosen>`
6. Update `hypr/theme.conf` symlink + `hyprctl reload`
7. Write `ghostty/themes/active.conf` + send `SIGUSR2` to running ghostty processes (live reload, no restart)
8. Update `superfile/theme/active.toml` symlink (with name remap via the palette's `superfileTheme` field)
9. `gsettings set org.gnome.desktop.interface gtk-theme "<theme>"` + `color-scheme prefer-dark`
10. `install -D -m 644` the GTK3 + GTK4 CSS files (Nautilus + nm-applet)
11. Update fish universal variables `fish_theme_primary` / `fish_theme_secondary` → all running fish sessions re-render their prompt instantly
12. Edit `waypaper/config.ini`'s `folder = ` line to the theme's wallpaper directory
13. Pick a random `.{png,jpg,jpeg,gif,webp}` from that directory → `swww img <chosen>` to apply
14. Update waypaper's saved `wallpaper = ` line so `--restore` works
15. `sddm-update-wallpaper <chosen>` copies the wallpaper to SDDM's shared path
16. `pkill waybar; waybar &`  +  `makoctl reload`
17. `nautilus --quit` — Nautilus caches its CSS at startup and only re-reads on full process exit

## Why all this complexity

Most desktop tools don't have a live "switch theme" command. The switcher works around that by managing file symlinks (or content) that the tools' built-in config-include mechanisms (`@import`, `source =`) re-resolve on reload. Where reload-in-place is impossible (waybar, mako, Nautilus), the script restarts the process.

## See also

- [[Home modules/Themes]] — palette schema
- [[Home modules/Desktop/WM/Hyprland]] — `themes.nix`
- [[Home modules/Desktop/WM/Waybar]] · [[Home modules/Desktop/WM/Wofi]] · [[Home modules/Desktop/WM/Mako]] · [[Home modules/Desktop/WM/Ghostty]] · [[Home modules/Desktop/WM/GTK]]
- [[Home modules/CLI/Superfile]] · [[Home modules/CLI/Fish]]
- [[Concepts/SDDM wallpaper sync]]

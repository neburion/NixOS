## Overview
Two tools handle wallpapers: **swww** (the engine that renders the wallpaper) and **waypaper** (the GUI picker that controls swww).

Configured in `home-modules/desktop/wm/wallpaper/`.

## How it works
1. `swww-daemon` starts on login via Hyprland `exec-once`
2. `waypaper --restore` also runs on login, restoring the last selected wallpaper
3. Open waypaper with `SUPER + W` to pick a new wallpaper

## Waypaper Config
File initialised at `~/.config/waypaper/config.ini` by a home-manager activation script — created once if missing, never overwritten. Waypaper writes back to it when the user picks a wallpaper, and `wofi-theme-switcher` updates the folder line.

| Setting | Value |
|---------|-------|
| Wallpaper folder | `~/Media/Wallpapers` |
| Backend | `swww` |
| Monitors | All |
| Default wallpaper | `Gruvbox-Face.png` |
| Columns | 3 |
| Transition type | `any` |
| Transition duration | 2s @ 60fps |
| Stylesheet | `~/.config/waypaper/style.css` |

## Notes
- Theme switching expects wallpapers organised into per-theme folders: `~/Media/Wallpapers/Catppuccin`, `Dark`, `Everforest`, `Gruvbox`, `Nord` (matching each theme's `wallpaperDir`).
- The waypaper config is runtime-owned — manual changes via the GUI persist.
- `waypaper` window opens as a centered float (800x540) via a Hyprland window rule

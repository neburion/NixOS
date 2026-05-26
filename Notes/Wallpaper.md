## Overview
Two tools handle wallpapers: **swww** (the engine that renders the wallpaper) and **waypaper** (the GUI picker that controls swww).

Configured in `home-modules/desktop/wm/wallpaper/`.

## How it works
1. `swww-daemon` starts on login via Hyprland `exec-once`
2. `waypaper --restore` also runs on login, restoring the last selected wallpaper
3. Open waypaper with `SUPER + W` to pick a new wallpaper

## Waypaper Config
File managed at `~/.config/waypaper/config.ini` with `force = true`.

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
- Wallpapers should be placed in `~/Media/Wallpapers/`
- The `force = true` on the config file means home-manager overwrites it on every rebuild — manual changes to the config won't persist
- `waypaper` window opens as a centered float (800x540) via a Hyprland window rule

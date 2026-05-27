## Overview
Hyprland is the Wayland compositor. Enabled system-wide in `modules/desktop/default.nix` and configured per-user in `home-modules/desktop/wm/hyprland/`.

## File Breakdown

| File | Purpose |
|------|---------|
| `default.nix` | Enables Hyprland, imports all sub-modules |
| `programs.nix` | Defines `$variable` aliases for every app/daemon |
| `auto-exec.nix` | `exec-once` startup list |
| `keybinds.nix` | All keybindings — see [[Keybinds]] |
| `monitors.nix` | Monitor layout and workspace assignment |
| `looks.nix` | Gaps, borders, animations, window rules, cursor |
| `env.nix` | Environment variables for Nvidia, GTK, cursor, Wayland |

## Monitors

| Variable | Output | Resolution | Position |
|----------|--------|------------|----------|
| `$builtInMonitor` | `eDP-1` | 1920x1080@120Hz | `0,0` |
| `$externalMonitor` | `HDMI-A-1` | 1920x1080@144Hz | `1920,0` |

Workspaces 1–5 → built-in monitor. Workspaces 6–10 → external monitor.

## Startup (exec-once)
- waybar
- mako
- swww-daemon
- waypaper --restore (restores last wallpaper)
- nm-applet
- blueman-applet

## Looks
- Layout: **dwindle** (pseudotile + preserve split)
- Gaps: 5px inner, 10px outer
- Borders: disabled (`border_size = 0`)
- Rounding: 5px
- Blur: enabled (size 3, 1 pass)
- Shadow: enabled
- Animations: custom easing curves (easeOutQuint based)

## Window Rules
| Rule | Condition |
|------|-----------|
| Float + pin + positioned bottom-right at 426x240 | Picture-in-Picture |
| Float + centered at 800x540 | waypaper |
| Tile | Steam main window |

## Environment Variables
| Variable | Value | Why |
|----------|-------|-----|
| `XDG_SESSION_TYPE` | `wayland` | Nvidia Wayland |
| `__GLX_VENDOR_LIBRARY_NAME` | `nvidia` | Nvidia GLX |
| `GDK_BACKEND` | `wayland,x11,*` | GTK app compatibility |
| `QT_QPA_PLATFORM` | `wayland;xcb` | Qt app compatibility |
| `SDL_VIDEODRIVER` | `wayland` | SDL game compatibility |
| `NIXOS_OZONE_WL` | `1` | Electron apps use Wayland (set system-wide) |
| `HYPRCURSOR_THEME` | `Adwaita` | Cursor theme |
| `HYPRCURSOR_SIZE` | `15` | Cursor size |

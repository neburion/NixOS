# Hyprland

`home-modules/desktop/wm/hyprland/` — Hyprland config split into 8 files by concern.

```
hyprland/
├── default.nix      enables hyprland + imports all sub-files
├── programs.nix     variables ($terminal, $appLauncher, …)
├── keybinds.nix     bind / bindm / bindel
├── auto-exec.nix    exec-once (waybar, mako, swww, applets, session restore)
├── monitors.nix     reads hostConfig.displays.monitors (data-driven)
├── looks.nix        workspaces, cursor, decoration, animations, windowrules
├── env.nix          HYPRCURSOR_*, XDG_*, NVIDIA_*, QT_QPA, …
├── themes.nix       generates one theme conf per palette + runtime symlink
└── session.nix      session save/restore service + timer
```

## Variables (`programs.nix`)

App/utility names exposed as `$variable` so keybinds.nix doesn't have to know packages.

| Variable | Value |
|---|---|
| `$statusBar` | `waybar` |
| `$notificationDaemon` | `mako` |
| `$wallpaperEngine` | `swww-daemon` |
| `$networkApplet` | `nm-applet` |
| `$bluetoothApplet` | `blueman-applet` |
| `$terminal` | `ghostty` |
| `$appLauncher` | `wofi --show drun` |
| `$themeSwitcher` | `wofi-theme-switcher` |
| `$powerMenu` | `wofi-power-menu` |
| `$fileManager` | `nautilus` |
| `$wallpaperManager` | `waypaper` |
| `$audioManager` | `pavucontrol` |
| `$taskManager` | `$terminal -e btop` |
| `$webBrowser` | `zen` |
| `$notesApp` | `obsidian` |
| `$messenger` | `signal` |
| `$discord` | `vesktop` |
| `$musicPlayer` | `spotify` |
| `$gameLauncher` | `heroic` |
| `$steamLauncher` | `steam` |

## Keybinds (`keybinds.nix`)

`$mod = SUPER`.

### Apps

| Key | Action |
|---|---|
| `SUPER+Return` | $terminal |
| `SUPER+Space` | $appLauncher |
| `SUPER+SHIFT+Space` | $themeSwitcher |
| `SUPER+ALT+Space` | $powerMenu |
| `SUPER+F` | $fileManager |
| `SUPER+W` | $wallpaperManager |
| `SUPER+A` | $audioManager |
| `SUPER+SHIFT+Escape` | $taskManager (btop) |
| `SUPER+B` | $webBrowser |
| `SUPER+N` | $notesApp |
| `SUPER+C` | $messenger |
| `SUPER+D` | $discord |
| `SUPER+M` | $musicPlayer |
| `SUPER+G` | $gameLauncher (heroic) |
| `SUPER+SHIFT+G` | $steamLauncher |
| `SUPER+P` | keepassxc |
| `SUPER+S` | localsend |

### Windows

| Key | Action |
|---|---|
| `SUPER+Backspace` | killactive |
| `SUPER+SHIFT+S` | togglesplit |
| `SUPER+T` | togglefloating |
| `SUPER+H/L/K/J` | move focus l / r / u / d |
| `SUPER+SHIFT+H/L/K/J` | move window l / r / u / d |
| `SUPER+mouse:272` | bindm move window |
| `SUPER+mouse:273` | bindm resize window |

### Workspaces

| Key | Action |
|---|---|
| `SUPER+1…0` | workspace 1…10 |
| `SUPER+SHIFT+1…0` | move window to workspace 1…10 |
| `SUPER+Escape` | switch to greeter (lock — see comment about busctl) |

Workspace ↔ monitor mapping (`looks.nix`): 1-5 on `$builtInMonitor`, 6-10 on `$externalMonitor`.

### Screenshot

| Key | Action |
|---|---|
| `Print` | area screenshot to `~/Media/Image/Screenshot/<timestamp>_screenshot.png` + clipboard |
| `Shift+Print` | full-screen screenshot, same destination |

### Audio / brightness (laptop keys, `bindel`)

| Key | Action |
|---|---|
| `XF86AudioRaiseVolume` | `wpctl set-volume …` +5 |
| `XF86AudioLowerVolume` | -5 |
| `XF86AudioMute` | toggle sink |
| `XF86AudioMicMute` | toggle source |
| `XF86MonBrightnessUp` | `brightnessctl s 10%+` |
| `XF86MonBrightnessDown` | `brightnessctl s 10%-` |

Also bound on `SUPER+= / SUPER+-` for desktop usage.

## Auto-exec (`auto-exec.nix`)

```nix
exec-once = [
  "$statusBar"            # waybar
  "$notificationDaemon"   # mako
  "$wallpaperEngine"      # swww-daemon
  "$wallpaperManager --restore"
  "$networkApplet"
  "$bluetoothApplet"
  "hypr-session-restore"  # see Concepts/Hyprland session restore
];
```

## Monitors (`monitors.nix`)

Data-driven from `hostConfig.displays.monitors` ([[Concepts/Host config (data flow)]]). For each role in the attrset, emits a `monitor =` line. Also sets `$builtInMonitor` and `$externalMonitor` variables that `looks.nix` references for workspace placement.

## Looks (`looks.nix`)

- Workspace-to-monitor mapping (1-5 builtin, 6-10 external)
- Cursor: Adwaita 15px, hide after 2s, no hardware cursors (NVIDIA quirk)
- General: 5px inner / 10px outer gaps, dwindle layout, no border, no tearing
- Decoration: 5px rounding, blur on (size 3, vibrancy 0.17), shadow on (range 4)
- Animations: easeOutQuint/almostLinear curves; named animations for windows, layers, workspaces, fade, zoom
- `xwayland.force_zero_scaling = true` (NVIDIA)
- Window rules:
  - Picture-in-Picture: floating, pinned, 426×240 at 73%/72%
  - Waypaper: floating, 800×540, centered
  - Steam: tile

Note in the file: `windowrulev2` deprecated in 0.42; the v2 syntax still works under `windowrule` keyword on 0.52+.

## Env (`env.nix`)

Cursor: `HYPRCURSOR_SIZE`, `HYPRCURSOR_THEME`, `XCURSOR_*` mirroring.
GTK: `GDK_SCALE`, `XDG_CURRENT_DESKTOP=Hyprland`, `XDG_SESSION_DESKTOP=Hyprland`, `ADW_DEBUG_COLOR_SCHEME=prefer-dark`.
NVIDIA: `XDG_SESSION_TYPE=wayland`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, `__GL_GSYNC_ALLOWED=1`, `__GL_VRR_ALLOWED=0`, `NVD_BACKEND=direct`, `GDK_BACKEND=wayland,x11,*`, `QT_QPA_PLATFORM=wayland;xcb`, `SDL_VIDEODRIVER=wayland`.

## Themes (`themes.nix`)

For each palette in `themes`, generates `~/.config/hypr/themes/<name>.conf` containing the decoration shadow color tinted from `bg`. Sources `~/.config/hypr/theme.conf` (a symlink owned by `wofi-theme-switcher`) for the active palette. `home.activation.initHyprTheme` creates the symlink pointing at `dark.conf` on first activation if missing.

## Session restore (`session.nix`)

Custom save/restore scripts for window state. Full writeup: [[Concepts/Hyprland session restore]].

## See also

- [[Modules/Desktop/WM]] — system-side enable
- [[Concepts/Theme switching]] — how `themes.nix` ties into the runtime switcher
- [[Concepts/Host config (data flow)]] — how `monitors.nix` gets monitor data
- [[Concepts/Hyprland session restore]]

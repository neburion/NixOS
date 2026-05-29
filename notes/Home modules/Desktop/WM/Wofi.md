# Wofi

`home-modules/desktop/wm/wofi/`.

```
wofi/
├── default.nix          enables wofi, generates per-theme css, packages scripts
├── config.nix           main wofi settings (uses sharedSettings)
├── shared-config.nix    sharedSettings (Nix attrs) + wofiArgs (CLI flag string)
├── style.nix            CSS template
└── scripts/
    ├── wofi-power-menu.nix
    └── wofi-theme-switcher.nix
```

## Shared config

`shared-config.nix` exposes two things:
- `sharedSettings` — attribute set for `programs.wofi.settings` (uses underscores, written as a config file)
- `wofiArgs` — same options serialised to a CLI flag string (uses hyphens, for `wofi --foo` invocations from scripts)

Both shapes describe the same prompt: ">", `35% × 30%` window, centered, single column, dark theme, etc. They mostly mirror each other; the CLI form is the subset that's valid as flags.

## Theme CSS

`default.nix` generates `~/.config/wofi/themes/<palette>.css` for each entry in `themes`. The style file imports the active one via the active.css symlink.

## Power menu

`wofi-power-menu` — five-option dmenu: Shutdown, Reboot, Suspend, Lock, Logout. Each calls `hypr-session-save` first ([[Concepts/Hyprland session restore]]) before the action — except `Suspend` (resumes in same session) and `Lock` (uses `busctl call … SwitchToGreeter`).

Triggered via `SUPER+ALT+Space` ([[Home modules/Desktop/WM/Hyprland]]).

## Theme switcher

`wofi-theme-switcher` — the most complex piece of the desktop. Full writeup in [[Concepts/Theme switching]].

Quick summary: lists every palette CSS file, dmenu-selects one, then in shell updates symlinks/files for wofi, waybar, mako, hyprland, ghostty, superfile, GTK, fish, waypaper, and triggers reloads.

Triggered via `SUPER+SHIFT+Space`.

## See also

- [[Concepts/Theme switching]] — the algorithm
- [[Home modules/Themes]] — the palette schema fed in

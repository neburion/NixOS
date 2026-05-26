# NixOS Config — Claude Code Rules

## Non-negotiable principles

**Declarative**: A fresh clone + `nixos-install` must reproduce the exact working system.
If a behavior requires a manual step after rebuild, that step must become a script or
activation hook in Nix. No mutable runtime setup that can't survive a wipe.

**Modular**: One concern per file. No god-files. If a module is doing more than one thing,
split it. Follow the existing directory conventions.

**Correct**: The user checks nothing. Be right the first time. WebSearch before using any
NixOS or HM option that might have changed between versions.

---

## Rebuild

```
sudo nixos-rebuild switch --flake $HOME/NixOS#pod042
```

Sudo is passwordless (`wheelNeedsPassword = false`). Never ask — just run it.

---

## Directory layout

```
hosts/pod042/          — hardware, user accounts, host-level config
modules/core/          — system services (audio, boot, hardware, networking, etc.)
modules/desktop/       — display manager, WM, fonts, apps — one file per concern
home-modules/cli/      — shell, git, editor, base packages, dir structure
home-modules/dev/      — compilers, dev tools, AI, scaffolding scripts
home-modules/desktop/  — per-user desktop: packages, mimeApps, XDG dirs
home-modules/desktop/wm/        — all WM components (one dir per component)
home-modules/desktop/wm/hyprland/  — one file per Hyprland concern
home-modules/themes/   — color palettes as Nix attrsets (no pkgs, no lib)
users/                 — home-manager user entry points (imports home-modules)
installer/             — live ISO scripts and disko layout
```

Every file in `modules/desktop/` is a single concern. If you add SDDM config, it goes in
`sddm.nix`, not `default.nix`. `default.nix` files are import-only aggregators.

---

## Theme system

Five themes: `catppuccin`, `dark`, `everforest`, `gruvbox`, `nord`.

Each palette in `home-modules/themes/<name>.nix` exports:
- `bg`, `surface`, `selection`, `fg` — color strings (hex)
- `wallpaperDir` — subdirectory under `~/Media/Wallpapers/` for this theme's pool

Theme files are pure Nix attrsets — no `pkgs`, no `lib`, no function arguments.

`home-modules/themes/default.nix` re-exports all palettes as `{ name = palette; }`.

Components that generate per-theme files (waybar, wofi, mako, ghostty, hyprland) all import
the palette map and use `lib.mapAttrs'` to produce one config file per theme. The active
theme is a runtime symlink or config line managed by `wofi-theme-switcher` — never by HM.

### Runtime-owned files (never manage with HM)

| File | Owner |
|------|-------|
| `~/.config/mako/config` | `wofi-theme-switcher` |
| `~/.config/hypr/theme.conf` | `wofi-theme-switcher` |
| `~/.config/ghostty/themes/active.conf` | `wofi-theme-switcher` |
| `~/.config/wofi/themes/active.css` | `wofi-theme-switcher` |
| `~/.config/waybar/themes/active.css` | `wofi-theme-switcher` |
| `~/.config/waypaper/config.ini` | waypaper + `wofi-theme-switcher` |
| `/var/cache/sddm-wallpaper/current` | `sddm-update-wallpaper` |

These files are created on first activation via `home.activation` (create-if-missing).
Subsequent rebuilds never touch them. This is the only permitted exception to declarativity —
it's explicitly documented here.

---

## Wallpaper system

Wallpapers are organized by theme under `~/Media/Wallpapers/<ThemeDir>/`.

| Theme | Directory |
|-------|-----------|
| catppuccin | `Catppuccin/` |
| dark | `Dark/` |
| everforest | `Everforest/` |
| gruvbox | `Gruvbox/` |
| nord | `Nord/` |

When `wofi-theme-switcher` changes the theme it also:
1. Updates the `folder =` line in `~/.config/waypaper/config.ini`
2. Picks a random wallpaper from the new pool and applies it via `swww img`
3. Calls `sddm-update-wallpaper` to copy it to `/var/cache/sddm-wallpaper/current`

When the user picks a wallpaper manually via waypaper GUI:
- waypaper fires `post_command = sddm-update-wallpaper` which syncs to SDDM

The SDDM login screen background reads from `/var/cache/sddm-wallpaper/current`.
This path is world-writable (mode 0666) so no sudo is needed for the sync script.
Initialized from `hyprland_kath.png` via `systemd.tmpfiles` on first boot.

---

## SDDM theme (`sddm-nyx-theme`)

Defined in `modules/desktop/sddm.nix`. A standalone Nix derivation that:
- Copies all assets from `pkgs.sddm-astronaut` (hyprland_kath style)
- Injects `Themes/nyx.conf` with our font, blur, and dynamic background settings
- Points `Background=file:///var/cache/sddm-wallpaper/current`

The theme name is `sddm-nyx-theme`. Do not change it without also updating
`services.displayManager.sddm.theme`.

---

## Session persistence

`hypr-session-save` / `hypr-session-restore` — defined in `home-modules/desktop/wm/hyprland/session.nix`.
Auto-saves every 5 min via a user systemd timer. Runs on Hyprland startup via `exec-once`.
Power menu saves before shutdown/reboot/logout.

---

## Git workflow

Always: `git add [files] && git commit -m "..." && git push`. No asking. Commit messages
explain the why, not the what.

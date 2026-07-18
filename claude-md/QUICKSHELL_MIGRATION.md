# Quickshell migration — living plan

Persistence doc for the multi-session migration off waybar/wofi/mako/awww/(hyprlock?) onto a single quickshell process. If a session is interrupted, pick up at the phase marked ⏳ or the first unchecked box.

## Status

| Phase | Description | State |
|-------|-------------|-------|
| 0 | Scaffolding (package, shell.qml generator, registry, themes) | ✅ |
| 1 | Bar (waybar parity) | ✅ |
| 2 | Notifications (mako replacement) | ✅ |
| 3 | Launcher + power menu + theme switcher (wofi replacement) | ✅ |
| 4 | Wallpaper (awww + waypaper replacement) | ✅ |
| 5 | OSD (volume + brightness) | ✅ |
| 6 | Lock screen (hyprlock replacement) | ⛔ deferred — see below |
| 7 | Cleanup + delete legacy modules | ✅ |

**Migration complete.** waybar, mako, wofi, awww, and waypaper are all removed from home.nix. Quickshell owns bar, notifications, launchers, wallpaper, and OSD.

## Non-negotiables

- Every change must stay Manifest+Additive compliant. See `ARCHITECTURE.md`.
- Rebuild after each meaningful change: `sudo nixos-rebuild switch --flake path:$HOME/NixOS#pod042`.
- Never delete a legacy module (waybar/wofi/…) until its quickshell replacement is verified end-to-end.
- Theme system is **option B**: quickshell owns theme state as the source of truth, pushes to external consumers (GTK, fish, ghostty, nvim, sddm) via `quickshell-theme-sync` script. Source of truth: `~/.local/state/quickshell/active-theme`.

## Architecture — locked in

**Single quickshell process, one config directory (`~/.config/quickshell/main/`), Nix-generated `shell.qml`.**

Nix module tree under `modules/home/desktop/quickshell/`:

```
default.nix              # aggregator
package.nix              # install pkgs.quickshell + activation for state files
registry.nix             # declares options.quickshell.{services,modules,widgets,extraQmlLines}
shell.nix                # generates shell.qml from the registry
theme-sync.nix           # quickshell-theme-sync shell script (external consumer sync)
themes.nix               # writes Common/Theme.qml singleton with all palettes

services/                # QML singletons (system integration)
  default.nix
  audio.nix              # Services/Audio.qml (pipewire/wpctl)
  battery.nix            # Services/Battery.qml (sysfs)
  brightness-state.nix   # Services/BrightnessState.qml (sysfs, path baked from hostConfig.backlight)
  hyprland-ipc.nix       # Services/HyprlandIpc.qml (socket2 events)
  power-profile.nix      # Services/PowerProfile.qml (powerprofilesctl)
  system-stats.nix       # Services/SystemStats.qml (cpu/mem/gpu via /proc + nvidia-settings)
  theme-state.nix        # Services/ThemeState.qml (owns active theme, persists to disk)
  time.nix               # Services/Time.qml
  wallpaper-state.nix    # Services/WallpaperState.qml (owns wallpaper path, persists to disk)

modules/                 # visible components
  default.nix
  bar/
    default.nix
    bar.nix              # Modules/Bar.qml — Variants per screen, height 38
    workspaces.nix       # Modules/BarWorkspaces.qml
    clock.nix            # Modules/BarClock.qml
    battery.nix          # Modules/BarBattery.qml
    hardware.nix         # Modules/BarHardwareGroup.qml (cpu/mem/gpu/audio)
    tray.nix             # Modules/BarTray.qml
    power-toggle.nix     # Modules/BarPowerToggle.qml
  launcher/
    default.nix
    app-launcher.nix     # Modules/AppLauncher.qml — IPC target "launcher"
    power-menu.nix       # Modules/PowerMenu.qml — IPC target "powerMenu"
    theme-switcher.nix   # Modules/ThemeSwitcher.qml — IPC target "themeSwitcher"
  notifications/
    default.nix
    center.nix           # Modules/NotificationCenter.qml — per-screen, 5s auto-dismiss
  osd/
    default.nix
    volume.nix           # Modules/OsdVolume.qml — appears on Audio change, 2s dismiss
    brightness.nix       # Modules/OsdBrightness.qml — appears on BrightnessState change, 2s dismiss
  wallpaper/
    default.nix
    background.nix       # Modules/WallpaperBackground.qml — per-screen, crossfade

widgets/
  default.nix
  capsule.nix            # Widgets/Capsule.qml
```

## Registry pattern

`registry.nix` declares:
- `options.quickshell.services` — attrset, one QML file per entry
- `options.quickshell.modules` — attrset, one QML file per entry
- `options.quickshell.widgets` — attrset, one QML file per entry
- `options.quickshell.moduleInstantiations` — list of QML snippets to place inside the top-level Scope in shell.qml

Each service/module/widget Nix file contributes an entry. `shell.nix` reads the aggregate and writes:
- `~/.config/quickshell/main/shell.qml` — top-level Scope instantiating everything
- `~/.config/quickshell/main/Services/<Name>.qml`
- `~/.config/quickshell/main/Modules/<Name>.qml`
- `~/.config/quickshell/main/Widgets/<Name>.qml`

Under strict Manifest+Additive we normally forbid `mkOption` in behavior modules. Registry options are the internal exception: they're not user-facing knobs, they're the mechanism that lets components register with the shell. Same latitude environment options get.

## Theme system — option B

**Source of truth:** `Services/ThemeState.qml` (singleton).

- Reads current theme name from `~/.local/state/quickshell/active-theme` on startup (defaults to `dark`).
- On theme change: writes new name to disk, fires QML signal for in-shell re-render, spawns `quickshell-theme-sync <name>`.
- `quickshell-theme-sync` handles all external consumers: GTK CSS, fish vars, ghostty theme, nvim active.lua, zed settings.json, superfile theme, wallpaper pick + state file write, SDDM wallpaper.

**Wallpaper state:** `Services/WallpaperState.qml` reads `~/.local/state/quickshell/wallpaper` (written by `quickshell-theme-sync`). `WallpaperBackground.qml` reacts to changes with 800ms crossfade.

## Phase 6 — Lock screen decision

**Decision: defer indefinitely, keep hyprlock.**

`Quickshell.Services.SessionLock` implements `ext-session-lock-v1` and can cover screens, but PAM authentication (password input → PAM verify → unlock) requires either:
1. A native Quickshell PAM binding (doesn't exist)
2. Spawning an external PAM helper and managing secure IPC to it
3. Replicating what hyprlock's C++ daemon does in QML

Complexity vs. benefit: hyprlock already looks good, is rock-solid, and matches the theme system. The lock screen is also security-critical — a homebrew QML implementation is higher risk. Deferring is the correct call.

`$locker = "hyprlock"` stays in programs.nix.

## Progress log

- **2026-07-13** — Plan drafted. Phase 0 in progress.
- **2026-07-13** — Phases 0–7 complete. waybar/mako/wofi/awww removed. Migration done.

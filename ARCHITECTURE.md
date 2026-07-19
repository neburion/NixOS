# Architecture

Fast-load map of this NixOS repo. Read this first, then jump to specific files.

## Philosophy — Manifest + Additive

Three layers, no leakage. Importing is enabling.

### Layers

| Layer           | Where                          | Contains                                                  |
|-----------------|--------------------------------|-----------------------------------------------------------|
| **Manifest**    | `hosts/*/`, `users/*/`         | Import lists only. Which capabilities exist on this box.  |
| **Behavior**    | `modules/system/`, `modules/home/` | What those capabilities do.                            |
| **Environment** | `hosts/*/hardware-layout/`     | Physical facts of the machine (displays, wifi, disk).     |

### Rules

1. **Manifests contain only imports.** No inline `programs.X.enable`, no `home.packages`, no `xdg.portal`. If it isn't an import, it belongs in a module.
2. **Behavior modules never expose user-facing options.** Importing IS enabling. Variants become separate files, not `mkOption` toggles.
   - *Documented exception:* `modules/home/desktop/quickshell-shared/registry.nix` declares `options.quickshell.{services, commons, modules, widgets, moduleInstantiations, shellExtraImports}`. These are **internal registration hooks** — each quickshell component contributes entries so `shell.nix` can materialize them into `~/.config/quickshell/main/`. Not user-facing knobs; they're the mechanism that lets a self-contained bar/launcher/OSD component register with the single quickshell process. Same latitude granted to Environment options.
3. **Environment modules MAY declare options.** That's the layer's job — publish per-host facts (displays, disks, wifi, GPU bus IDs) that behavior modules read.
4. **Cross-cutting data flows as module arguments,** not options. See `themes` injected in `flake.nix:55-58`.
5. **`default.nix` is pure aggregation.** `imports = [ ... ]` and nothing else.
6. **One concern per file.** `waybar/config.nix`, `waybar/style.nix`, `waybar/themes.nix` — not one `waybar.nix`.
7. **System vs. home split is mirrored.** `modules/system/` for NixOS-level, `modules/home/` for Home Manager. Same hierarchy under both.

### Operating rules (for me, Claude)

- **Test every change.** After editing anything under this tree, run `rebuild` (the bash wrapper in `modules/home/cli/nixos-scripts.nix`, on PATH as `/etc/profiles/per-user/neburion/bin/rebuild`). Don't hand off untested work.
- **Research online when in doubt.** If a NixOS option, home-manager module, or upstream package behavior isn't obvious, look it up (WebSearch / WebFetch) before committing. Two failed attempts at the same problem means stop and search.
- **`path:` scheme, not github URL.** The scripts already hardcode `path:$HOME/NixOS#$(hostname -s)`. As of 2026-07-19 both pod042 and print-server have their hardware-config committed, so `github:...` is technically safe now — but `path:` remains preferred (picks up uncommitted local edits, no round-trip to GitHub).

## Entry points

- **`flake.nix`** — defines `mkSystem { host, ... }` helper; builds each host by importing `hosts/${host}/configuration.nix`. Injects `networking.hostName = host;` as a module so hosts stay pure. Threads `zen-browser`, `nvf`, `inputs`, and `themes` down via `specialArgs` / `sharedModules`.
- **`hosts/<host>/configuration.nix`** — pure manifest. Imports only.
- **`hosts/<host>/hardware-layout/`** — environment (displays, wifi, disk, GPU).
- **`hosts/<host>/hardware-configuration.nix`** — placeholder, git-ignored, real one lives in `/etc/nixos/`.
- **`users/<user>/default.nix`** — pure manifest. Aggregates `account.nix`, `home.nix`, and any user-specific system modules.
- **`users/<user>/account.nix`** — the `users.users.<user>` block (identity, groups, shell, bootstrap password if applicable).
- **`users/<user>/home.nix`** — the `home-manager.users.<user>.imports = [ ... ]` list.

## Hosts

| Host          | Purpose                       | Boot            | User(s)             |
|---------------|-------------------------------|-----------------|---------------------|
| `pod042`      | Main laptop                   | `limine`        | `neburion`          |
| `print-server`| Headless family print server  | `systemd-boot`  | `printer`           |
| `installer`   | Live USB ISO                  | isoImage output | (built via `iso/`)  |

## Module tree (behavior layer)

### `modules/system/` — NixOS

```
nixos.nix                system-level nix settings
locale.nix               timezone / locale
audio.nix                pipewire
bluetooth.nix
flatpak.nix
power-profiles.nix
always-on.nix            keep host awake: no lid handling, no sleep targets

boot/                    grub, systemd-boot, limine (pick one)
networking/              networkmanager, ssh, syncthing, localsend
hardware/                nvidia (reads config.gpu.*), touchpad, brightness, logitech
shell/                   fish (system-level enable for user login shells)
printing/                aggregator → canon.nix (CUPS + tmpfiles), web-server.nix,
                         canon-cups-ufr2/ (local overlay package: v6.00 driver
                         + int→char patch, wired via flake overlay)
desktop/                 aggregator → de/, fonts.nix, gaming/
desktop/de/              dconf, hyprland (system-level), sddm, wayland-env, xdg-portal
desktop/gaming/          steam
```

### `modules/home/` — Home Manager

```
base.nix                 home.stateVersion

cli/                     shell/fish, neovim/*, btop, tree, fastfetch, superfile,
                         compression, fonts, xdg
cli/ai/                  claude-code
cli/packager/            appimage, flatpak

desktop/wm/hyprland/     env, input, keybinds, looks, monitors, programs, session,
                         themes, screenshot-tools, hyprlock, auto-exec, enable,
                         window-rules
desktop/theming/gtk/     per-theme GTK packages + config/dconf/glib/css
desktop/clipboard/       wl-clipboard
desktop/terminal/        ghostty
desktop/tray-apps/       libnotify (nm-applet/blueman replaced by native quickshell widgets)
desktop/presets/         aggregator presets — hyprland-tmp.nix (NieR sepia
                         rice), hyprland-minimal-qs.nix (plain quickshell),
                         hyprland-minimal.nix (waybar legacy/fallback)
desktop/bar/quickshell/  Bar, BarClock, BarWorkspaces, BarBattery, BarHardwareGroup,
                         BarTray, BarPowerToggle, BarWifi, BarBluetooth, Capsule widget
                         (each .nix owns its service singleton + widget; self-contained)
desktop/launcher/quickshell/  AppLauncher, ThemeSwitcher, PowerMenu
desktop/notifications/quickshell/  NotificationCenter
desktop/osd/quickshell/  OsdVolume, OsdBrightness (+ BrightnessState service)
desktop/wallpaper/quickshell/  WallpaperPicker (+ WallpaperState service)
desktop/quickshell-shared/  shared core (imported by every component's default.nix;
                         NixOS module system deduplicates the import automatically)
                           core.nix — aggregator for shared infrastructure
                           package.nix — install quickshell + state dir activation
                           registry.nix — options.quickshell.{services,commons,modules,
                                          widgets,moduleInstantiations,shellExtraImports}
                           shell.nix — materializes all registry entries into
                                       ~/.config/quickshell/main/{Services,Common,
                                       Modules,Widgets}/ + shell.qml
                           theme-sync.nix — quickshell-theme-sync shell script
                           themes.nix — Common/Theme.qml (palettes baked at build time)
                           services/theme-state.nix — ThemeState singleton (source of truth)
                           services/audio.nix — Audio singleton (shared: bar + OSD)
desktop/utils/           nautilus, loupe, celluloid, pavucontrol, libre-office,
                         peripherals/{razer-genie,solaar}

dev/                     git, direnv, gcloud, ides/zed, game-engines/godot,
                         languages/{c-cpp,nix,odin,python,rust,zig}

gaming/                  heroic, minecraft/{prism-launcher}
art/                     aseprite, blender
apps/                    zen-browser, keepassxc, spotify, obsidian, vesktop,
                         signal, localsend
themes/                  attrset export: catppuccin, dark, everforest,
                         gruvbox, nord
```

## Themes — cross-cutting data pattern

`modules/home/themes/default.nix` exports an attrset:
```
{ catppuccin = import ./catppuccin.nix; dark = import ./dark.nix; ... }
```

Each theme file is pure data — a palette + wallpaper dir + per-tool theme names:
```
{ bg; surface; selection; fg; wallpaperDir; gtkTheme;
  fishPrimary; fishSecondary; superfileTheme; nvimTheme; zedTheme; }
```

`flake.nix` injects `themes` into every home-manager module via `_module.args.themes`.

Consumers **generate their own artifacts** from `themes`. Examples:
- `quickshell-shared/themes.nix` — writes `Common/Theme.qml` with all palettes baked in.
- `quickshell-shared/theme-sync.nix` — writes `quickshell-theme-sync` script (GTK CSS paths baked in).
- `hyprland/themes.nix` — writes `xdg.configFile."hypr/themes/<name>.conf"` per palette.

The **active** theme is owned by `Services/ThemeState.qml` (source of truth). Persisted to `~/.local/state/quickshell/active-theme`. On change: QML re-renders reactively, then `quickshell-theme-sync <name>` propagates to GTK, fish, ghostty, nvim, zed, superfile, SDDM, and wallpaper. Boot default is `dark`.

The **active wallpaper** follows the same pattern in `Services/WallpaperState.qml`: persisted to `~/.local/state/quickshell/wallpaper` (written by `quickshell-theme-sync` when the theme changes, or by the wallpaper picker directly). `WallpaperBackground.qml` watches this file and reacts with an 800ms crossfade. Same "singleton owns state, external consumers subscribe" pattern as the theme system.

## Environment options currently declared

Declared and set per host under `hosts/<host>/hardware-layout/`:

- `displays.primary` : attrs (width, height)
- `displays.monitors` : attrs of `{ name; mode; position; scale; }`
- `gpu.prime.intelBusId` / `gpu.prime.nvidiaBusId` : str (PCI addresses)
- `gpu.openKernelModule` : bool (Turing+ default true, flip for Pascal)
- `gpu.externalMonitorOnDgpu` : bool (disables fine-grained runtime PM if true)
- `backlight.sysfsBrightnessPath` / `backlight.sysfsMaxBrightnessPath` : str (sysfs paths)

Displays and backlight are surfaced to home-manager via `flake.nix` (`hostConfig.displays.monitors`, `hostConfig.backlight`). GPU options are read by `modules/system/hardware/nvidia.nix`. Backlight options are read by `quickshell-shared/services/brightness-state.nix` (baked into QML at build time).

## Conventions cheat sheet

- `default.nix` in a directory = aggregator. Never has config.
- New app? Add `modules/home/apps/<name>.nix`, then add one import line to `users/neburion/home.nix`.
- New theme? Add `modules/home/themes/<name>.nix` (data only), then add it to `modules/home/themes/default.nix`.
- New host? Copy `hosts/pod042/` skeleton, minimize imports, put physical facts in `hardware-layout/`, add to `flake.nix` `nixosConfigurations`. Do NOT add `networking.hostName` — the flake injects it.
- New user? Copy `users/neburion/` skeleton, keep `default.nix` as pure aggregator, put identity in `account.nix`, put HM imports in `home.nix`.
- Swap a component (e.g. waybar → quickshell)? Delete the waybar import, add the quickshell import. Don't touch either module.
- Swap a shell provider (bar, wallpaper, launcher)? See **Shell auto-wiring** below — only the import changes.

## Shell auto-wiring

Hyprland's keybinds and exec-once entries use **shell variables** (`$statusBar`, `$appLauncher`, `$wallpaperManager`, etc.) defined in `hyprland/keybinds.nix` and `hyprland/auto-exec.nix`. These variables are **never set in those files**. Instead, whichever shell provider module is imported contributes them.

Each quickshell component `default.nix` contributes its own variable(s):

| Variable            | Value                                    | Provider                            |
|---------------------|------------------------------------------|-------------------------------------|
| `$statusBar`        | `quickshell`                             | `bar/quickshell/default.nix`        |
| `$appLauncher`      | `qs ipc call launcher toggle`            | `launcher/quickshell/default.nix`   |
| `$themeSwitcher`    | `qs ipc call themeSwitcher toggle`       | `launcher/quickshell/default.nix`   |
| `$powerMenu`        | `qs ipc call powerMenu toggle`           | `launcher/quickshell/default.nix`   |
| `$wallpaperManager` | `qs ipc call wallpaperPicker toggle`     | `wallpaper/quickshell/default.nix`  |

**Consequence:** importing `presets/hyprland-minimal-qs.nix` in `users/*/home.nix` automatically wires exec-once (starts the bar), all keybinds (launcher, theme, power, wallpaper) — without touching `keybinds.nix`, `auto-exec.nix`, or `programs.nix`.

**Swap rule:** to replace quickshell with another shell, remove the quickshell import and add a new module that provides the same variables. `keybinds.nix` and `auto-exec.nix` update with zero changes.

This mirrors how `hardware-layout/` auto-configures monitors: the per-host environment module publishes facts, behavior modules consume them. Shell provider modules publish Hyprland variable facts; keybinds/exec consume them.

## Deferred decisions

- **Lock screen**: quickshell is not used for locking. `Quickshell.Services.SessionLock` implements `ext-session-lock-v1` but PAM authentication requires either a native binding (doesn't exist) or a custom PAM helper with secure IPC — complexity not worth the benefit since hyprlock already looks good and is security-critical. `$locker = "hyprlock"` stays in programs.nix indefinitely.

## Known security debt

- `hosts/*/hardware-layout/wifi-layout.nix` — wifi PSK in plaintext. Legitimate under Environment layer (per-host physical fact), but sensitive if the repo goes public. Migration path: `sops-nix` with SSH-host-key-derived age recipients.
- `users/printer/account.nix` — `initialPassword = "1234"` in plaintext. Deliberately trivial for a LAN-only family kiosk; not a real secret. If ever elevated, switch to `hashedPasswordFile` fed by sops.

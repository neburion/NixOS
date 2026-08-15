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
   - *Documented exceptions (internal registration hooks, not user knobs):*
     - `modules/home/desktop/quickshell-shared/registry.nix` — `options.quickshell.{services, commons, modules, widgets, moduleInstantiations, shellExtraImports}`. Each quickshell component contributes entries so `shell.nix` can materialize them into `~/.config/quickshell/main/`.
     - `modules/home/desktop/theme-switcher/registry.nix` — `options.themeHooks`. Each consumer contributes a `theme-hook-<name>` shell script; the switcher bakes each hook's store path into the generated `theme-set` script so no runtime directory scan is needed.
     - Same latitude granted to Environment options.
3. **Environment modules MAY declare options.** That's the layer's job — publish per-host facts (displays, disks, wifi, GPU bus IDs) that behavior modules read.
4. **Cross-cutting data flows as module arguments,** not options. See `themes` injected in `flake.nix:55-58`.
5. **`default.nix` is pure aggregation.** `imports = [ ... ]` and nothing else.
6. **One concern per file.** `waybar/config.nix`, `waybar/style.nix`, `waybar/themes.nix` — not one `waybar.nix`.
7. **System vs. home split is mirrored.** `modules/system/` for NixOS-level, `modules/home/` for Home Manager. Same hierarchy under both.

### Fleet principle — no host is special

Every host is a peer. There is no control node, no "primary" that other hosts depend on. Every host is on the fleet **Tailscale** tailnet (via `modules/system/networking/tailscale.nix` reading a shared `tailscale-auth-key` from `secrets/common.yaml`), so bare hostnames resolve via MagicDNS from anywhere in the world and `rebuild <host>` works over the tailnet interface regardless of the physical network the target is on. Consequences:

- **Any host** can rebuild itself (`rebuild`) or any host it has SSH to (`rebuild <hostname>` — uses `nixos-rebuild --target-host`, no rsync).
- **Any host** has the tooling (`rebuild`, `cf-reconcile`, future `r2-reconcile`, etc.) via `modules/home/cli/nixos-scripts.nix`.
- **Any host** with the fleet age key at `/var/lib/sops-nix/key.txt` can decrypt every secret in the repo (per the single-fleet-key design — see the Secrets section).
- **Adding a host:** copy a `hosts/<existing>/` skeleton, edit imports for the new machine, add one line to `flake.nix` `nixosConfigurations`. No cross-host references need editing.
- **Removing a host:** delete `hosts/<gone>/` and its `flake.nix` entry. Nothing else references it (except optional SSH `authorized_keys`, which decays harmlessly).
- **Adding a user:** copy `users/<existing>/` skeleton, edit imports, reference from any host's manifest that should have that user.
- **Removing a user:** delete `users/<gone>/`, remove references. Sops secrets are host-scoped, not user-scoped, so nothing to prune there.

**Cross-host coupling is via `secrets/common.yaml` (declared inputs) and reconciled outputs written back into `secrets/<host>.yaml`.** No host reads another host's config directly; the shared surface is the encrypted secrets layer.

### Operating rules (for me, Claude)

- **Test every change.** After editing anything under this tree, run `rebuild` (the bash wrapper in `modules/home/cli/nixos-scripts.nix`, on PATH as `/etc/profiles/per-user/neburion/bin/rebuild`). Don't hand off untested work.
- **Research online when in doubt.** If a NixOS option, home-manager module, or upstream package behavior isn't obvious, look it up (WebSearch / WebFetch) before committing. Two failed attempts at the same problem means stop and search.
- **`path:` scheme, not github URL.** The scripts already hardcode `path:$HOME/NixOS#$(hostname -s)`. As of 2026-07-19 both pod042 and home-server have their hardware-config committed, so `github:...` is technically safe now — but `path:` remains preferred (picks up uncommitted local edits, no round-trip to GitHub).
- **Remote deploys to any host.** `rebuild <hostname>` from any fleet workstation: uses `nixos-rebuild --target-host` over SSH, no rsync. Fleet SSH config (modules/system/networking/ssh.nix) maps hostnames to `server-admin` for server-class hosts. Passwordless wheel on servers means non-interactive activation.

## Entry points

- **`flake.nix`** — defines `mkSystem { host, ... }` helper; builds each host by importing `hosts/${host}/configuration.nix`. Injects `networking.hostName = host;` as a module so hosts stay pure. Threads `zen-browser`, `nvf`, `inputs`, and `themes` down via `specialArgs` / `sharedModules`.
- **`hosts/<host>/configuration.nix`** — pure manifest. Imports only.
- **`hosts/<host>/hardware-layout/`** — environment (displays, wifi, disk, GPU).
- **`hosts/<host>/hardware-configuration.nix`** — placeholder, git-ignored, real one lives in `/etc/nixos/`.
- **`users/<user>/default.nix`** — pure manifest. Aggregates `account.nix`, `home.nix`, and any user-specific system modules.
- **`users/<user>/account.nix`** — the `users.users.<user>` block (identity, groups, shell, bootstrap password if applicable).
- **`users/<user>/home.nix`** — the `home-manager.users.<user>.imports = [ ... ]` list.

## Hosts

| Host          | Purpose                                                | Boot            | User(s)             |
|---------------|--------------------------------------------------------|-----------------|---------------------|
| `pod042`      | Main laptop                                            | `limine`        | `neburion`          |
| `home-server` | Headless family server: print/scan web UI              | `systemd-boot`  | `server-admin`      |
| `installer`   | Live USB ISO                                           | isoImage output | (built via `iso/`)  |

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
printing/                aggregator → canon.nix (CUPS + tmpfiles), web-server.nix
                         (Flask print/scan web UI on :80, PRG + multi-page SANE
                         scan → PDF via img2pdf), canon-cups-ufr2/ (local overlay
                         package: v6.00 driver + int→char patch, wired via flake
                         overlay)
desktop/                 aggregator → de/, fonts.nix, gaming/
desktop/de/              dconf, hyprland (system-level), sddm, wayland-env, xdg-portal
desktop/gaming/          steam
```

### `modules/home/` — Home Manager

```
base.nix                 home.stateVersion

cli/                     shell/fish, neovim/*, btop, tree, fastfetch, superfile,
                         compression, fonts
cli/ai/                  claude-code (pinned to pkgs.unstable via flake overlay)
cli/packager/            flatpak

desktop/wm/hyprland/     env, input, keybinds, looks, monitors, programs, session,
                         themes, screenshot-tools, hyprlock, auto-exec, enable,
                         window-rules
desktop/theming/gtk/     per-theme GTK packages + config/dconf/glib/css
desktop/clipboard/       wl-clipboard
desktop/terminal/        ghostty
desktop/tray-apps/       libnotify (nm-applet/blueman replaced by native quickshell widgets)
desktop/presets/         aggregator presets — clean.nix (NieR sepia
                         rice), simple.nix (plain quickshell),
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

dev/                     git, direnv, tokei, ides/intellij, game-engines/godot,
                         languages/{c-cpp,nix,python}

gaming/                  heroic, sober, minecraft/{prism-launcher}
art/                     aseprite, blender
apps/                    zen-browser, keepassxc, spotify, obsidian, marktext,
                         vesktop, signal, localsend, thunderbird
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

**Consequence:** importing `presets/simple.nix` in `users/*/home.nix` automatically wires exec-once (starts the bar), all keybinds (launcher, theme, power, wallpaper) — without touching `keybinds.nix`, `auto-exec.nix`, or `programs.nix`.

**Swap rule:** to replace quickshell with another shell, remove the quickshell import and add a new module that provides the same variables. `keybinds.nix` and `auto-exec.nix` update with zero changes.

This mirrors how `hardware-layout/` auto-configures monitors: the per-host environment module publishes facts, behavior modules consume them. Shell provider modules publish Hyprland variable facts; keybinds/exec consume them.

## Deferred decisions

- **Lock screen**: quickshell is not used for locking. `Quickshell.Services.SessionLock` implements `ext-session-lock-v1` but PAM authentication requires either a native binding (doesn't exist) or a custom PAM helper with secure IPC — complexity not worth the benefit since hyprlock already looks good and is security-critical. `$locker = "hyprlock"` stays in programs.nix indefinitely.

## Secrets — sops-nix layer

Encrypted secrets live in `secrets/*.yaml`, one file per host, matched by the `sops.defaultSopsFile` computed from `config.networking.hostName` in `modules/system/security/sops.nix`. Every secret is encrypted to a single fleet-wide age recipient declared in `.sops.yaml`. Consequence: any host holding the private key can decrypt every secret — intentional single-fleet trust boundary. Don't add low-trust hosts.

**Key material:**
- `secrets/age-key.enc` — the age *private* key, encrypted at rest with a passphrase using openssl AES-256-CBC + PBKDF2 (600k iters). Committed to the repo. Safe to publish only insofar as the passphrase is strong.
- `/var/lib/sops-nix/key.txt` — plaintext age key on each host, mode 0400 root:root. sops-nix reads it at activation to decrypt `secrets/<host>.yaml` into `/run/secrets/<name>`.
- The passphrase itself lives in KeePassXC; brain-memorized copy is optional.

**How each host gets the key:**
- Fresh install: `iso/scripts/nixinstall.sh` prompts for the passphrase, decrypts `secrets/age-key.enc` via `openssl enc -d`, and installs to `/mnt/var/lib/sops-nix/key.txt` before `nixos-install`. Wrong passphrase = bail before disk wipe.
- Existing host that needs re-provisioning: decrypt on any dev machine and `sudo install -Dm400 - /var/lib/sops-nix/key.txt`.

**Rotating the passphrase (routine hygiene):**
```
openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in secrets/age-key.enc -pass pass:OLD | \
openssl enc    -aes-256-cbc -pbkdf2 -iter 600000 -salt -out secrets/age-key.enc.new -pass pass:NEW
mv secrets/age-key.enc.new secrets/age-key.enc
```
No host changes needed — the age keypair is unchanged, only its at-rest envelope.

**Rotating the age keypair (only if key leaks):** generate new keypair, update `.sops.yaml`, `sops updatekeys secrets/*.yaml`, re-encrypt private key, redistribute `/var/lib/sops-nix/key.txt` to every host, rebuild each.

## Known security debt

- `hosts/*/hardware-layout/wifi-layout.nix` — wifi PSK in plaintext. Migration path: move into `secrets/<host>.yaml` and reference via `sops.secrets` (once wifi module reads from a file path instead of an inline string).
- `users/server-admin/account.nix` — `initialPassword = "1234"` in plaintext. Deliberately trivial for headless server-class hosts (LAN-only + auth-gated CF tunnel); not a real secret. If ever elevated, switch to `hashedPasswordFile` fed by sops.

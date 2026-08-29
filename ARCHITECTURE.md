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
     - `modules/home/desktop/quickshell-shared/registry.nix` — `options.quickshell.{services, commons, modules, widgets, moduleInstantiations, shellExtraImports}`. Each quickshell component contributes entries so `shell.nix` can materialize them into `~/.config/quickshell/main/`. **The value type is `lines`, which merges by concatenation, not by conflict.** Two modules registering the same key (e.g. two presets each defining `services.WallpaperState`) do not error — their QML is glued end to end into one file with two `pragma Singleton` blocks, and quickshell fails at load with a syntax error pointing at the seam. Only import one preset's components at a time.
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
- **Any host** has the tooling (`rebuild`, `cf-reconcile`, future `r2-reconcile`, etc.) via `modules/home/cli/nixos-scripts/`.
- **Any host** with the fleet age key at `/var/lib/sops-nix/key.txt` can decrypt every secret in the repo (per the single-fleet-key design — see the Secrets section).
- **Adding a host:** copy a `hosts/<existing>/` skeleton, edit imports for the new machine, add one line to `flake.nix` `nixosConfigurations`. No cross-host references need editing.
- **Removing a host:** delete `hosts/<gone>/` and its `flake.nix` entry. Nothing else references it (except optional SSH `authorized_keys`, which decays harmlessly).
- **Adding a user:** copy `users/<existing>/` skeleton, edit imports, reference from any host's manifest that should have that user.
- **Removing a user:** delete `users/<gone>/`, remove references. Sops secrets are host-scoped, not user-scoped, so nothing to prune there.

**Cross-host coupling is via `secrets/common.yaml` (declared inputs) and reconciled outputs written back into `secrets/<host>.yaml`.** No host reads another host's config directly; the shared surface is the encrypted secrets layer.

### Operating rules (for me, Claude)

- **Test every change with `trebuild`, not `rebuild`.** After editing anything under this tree, run `trebuild` (the bash wrappers live in `modules/home/cli/nixos-scripts/`, on PATH under `/etc/profiles/per-user/neburion/bin/`). Don't hand off untested work. See the next rule for why `rebuild` is the wrong tool here.
- **`rebuild` deploys the CLOUD, so push before you rebuild.** As of commit 4c57131 the two scripts read from different places, and this is the single easiest way to think a change landed when it didn't:

  | Script | Flake source | Sees uncommitted edits? |
  |---|---|---|
  | `trebuild` | `path:$HOME/NixOS` | **Yes** — local working tree |
  | `rebuild` | `github:neburion/NixOS` | **No** — origin/master only |

  So `rebuild` only deploys work that is **committed *and* pushed**. Local edits that are merely committed are just as invisible as uncommitted ones. Either `git push` first, or use `trebuild`.

  `warnIfLocalDiverged` in `nixos-scripts/lib.nix` guards this: it checks a dirty working tree (`git status --porcelain`) *and* unpushed commits (`git rev-list --count '@{upstream}..HEAD'`), listing the offending files. It warns, it doesn't block — you may knowingly redeploy the cloud version while carrying unrelated dev config.

  Until 2026-08-15 it only checked the second condition, so a dirty tree scored 0 and passed silently — `rebuild` printed a fresh store path and `Done.` while deploying the cloud version, a wholly convincing success message for a no-op. The lesson outlives the fix: **`Done.` is not proof.** Verify the generated artifact (e.g. `grep` the value you changed in `~/.config/hypr/hyprland.conf`). Every script that reads a `github:` flake passes `--refresh` to bypass nix's 1-hour tarball cache, so `git push && rebuild` does pick up the just-pushed commit. That means `rebuild` and `nixflash`; `trebuild` reads the local tree and needs no such flag.

  `nixflash` was the exception until 2026-08-16 — it moved into this directory in `0f97cf0` without picking up the flag, so `git push && nixflash` could build an ISO from the *previous* HEAD while printing an entirely normal `Built: /nix/store/...` line. Same failure shape as the dirty-tree bug above, which is the recurring hazard of the cloud-flake design: **when the source is remote, a convincing success message tells you a build happened, never that it built what you just wrote.**
- **Research online when in doubt.** If a NixOS option, home-manager module, or upstream package behavior isn't obvious, look it up (WebSearch / WebFetch) before committing. Two failed attempts at the same problem means stop and search.
- **Remote deploys to any host.** `rebuild <hostname>` from any fleet workstation: uses `nixos-rebuild --target-host` over SSH, no rsync. Fleet SSH config (modules/system/networking/ssh.nix) maps hostnames to `server-admin` for server-class hosts. Passwordless wheel on servers means non-interactive activation. `rebuild-all` does the whole fleet in one pass — remotes first and the local host last, skipping anything powered off, and one failure doesn't abort the rest. Both share `deploy_host` from `nixos-scripts/lib.nix`, so their flags cannot drift apart.

## Entry points

- **`flake.nix`** — defines `mkSystem { host, ... }` helper; builds each host by importing `hosts/${host}/configuration.nix`. Injects `networking.hostName = host;` as a module so hosts stay pure. Threads `zen-browser`, `nvf`, `inputs`, and `themes` down via `specialArgs` / `sharedModules`.
- **`hosts/<host>/configuration.nix`** — pure manifest. Imports only.
- **`hosts/<host>/hardware-layout/`** — environment (displays, wifi, disk, GPU).
- **`hosts/<host>/hardware-configuration.nix`** — **committed**, one real file per host. (This line used to claim the file was git-ignored with the real one in `/etc/nixos/`; it isn't, and `.gitignore` never mentioned it.) The distinction matters because `rebuild` deploys from `github:`, so the *committed* file is what a remote deploy uses — a machine whose generated hardware config was never copied back into the repo gets deployed a config describing someone else's disks. `nixinstall.sh` writes the generated file into the repo copy at `/mnt/etc/nixos` and installs via `path:`, so the **install** is correct; it's the first `rebuild` afterwards that bites. Copy the generated file back and commit it as a post-install step.
- **`users/<user>/default.nix`** — pure manifest. Aggregates `account.nix`, `home.nix`, and any user-specific system modules.
- **`users/<user>/account.nix`** — the `users.users.<user>` block (identity, groups, shell, bootstrap password if applicable).
- **`users/<user>/home.nix`** — the `home-manager.users.<user>.imports = [ ... ]` list.

## Hosts

| Host              | Purpose                                                | Boot            | User(s)             |
|-------------------|--------------------------------------------------------|-----------------|---------------------|
| `pod042`          | Main laptop                                            | `limine`        | `neburion`          |
| `home-server`     | Headless family server: print/scan web UI              | `systemd-boot`  | `server-admin`      |
| `personal-server` | Headless personal server: Elden Ring tracker           | `systemd-boot`  | `server-admin`      |
| `installer`       | Live USB ISO                                           | isoImage output | (built via `iso/`)  |

`home-server` and `personal-server` are the same *class* of machine (old laptop,
headless, `server-admin`, always-on) split by *audience*: the family depends on
one, so it stays boring; the other is mine to break. Per the fleet principle
neither depends on the other — the split is about blast radius, not topology.
`personal-server` runs two services, and **neither of them lives in this repo**.
Both are ordinary projects on GitHub carrying an `app.json`; `apps/platform.nix`
reads that manifest and generates the unit, user, state directory, credential
wiring, firewall rule and tunnel. See *The app platform* below. The **Elden Ring
tracker** is on the tailnet at `http://personal-server:8777` and publicly at
`https://eldenring.azuresalt.app` through a Cloudflare tunnel; it is the first
host to expose something whose gate is not solely a Cloudflare Access policy —
the app carries HTTP Basic Auth from the `elden-ring-tracker-password` sops
secret and refuses to bind a non-loopback address without it, so a missing
Access policy weakens the gate rather than removing it. Set the policy anyway. The **media tracker** is at `http://personal-server:8778`,
`https://media.azuresalt.app` and `https://reading.azuresalt.app` — two tunnels
onto one service, not a redirect — behind the same Basic Auth and fail-closed
bind check. It wants an Access policy more than the Elden Ring tracker does: a
wiped playthrough is re-seedable, a deleted series takes its chapter history
with it.

### The `installer` host

`iso/` is a host like any other — `iso/configuration.nix` is a pure manifest.
Two things make it look different:

- **You build a different attribute.** `.config.system.build.isoImage` instead
  of `.toplevel`. `nixflash` wraps that build plus the `dd`.
- **It deliberately bypasses `mkSystem`.** No `specialArgs`, no home-manager,
  no overlays — so it *cannot* import most of `modules/system/`, which assume
  `inputs`. That's why `iso/nix-experimental.nix` re-states the one nix setting
  it needs instead of importing `modules/system/nixos.nix`.

Its scripts (`nixinstall`, `nixshrink`) are live-USB-only by nature and carry
their own `runtimeInputs`, so the ISO needs no shared package list.

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

apps/platform.nix        the app platform: projects that live in their own
                         repos, deployed here. A host names the repos in
                         hardware-layout/apps-layout.nix; each repo carries an
                         app.json at its root declaring a port, its URLs, which
                         secrets it wants and whether it needs state, and this
                         module turns that into a systemd unit, a system user,
                         /var/lib/<name>, LoadCredential wiring, the tailnet
                         firewall rule and the Cloudflare tunnel.

                         The manifest is bounded, not obeyed: ports must sit in
                         8700-8799, hostnames under azuresalt.app, secrets
                         resolve to sops keys prefixed with the app's own name,
                         the runtime must be one of a known few, and `run` may
                         not contain shell metacharacters. A repo can only ever
                         reach its own password, and push access to it is not
                         code execution here.

                         Contract for an app: listen on $PORT, keep durable
                         things in $STATE_DIR, read secrets from
                         $CREDENTIALS_DIRECTORY/<name>, exit non-zero if it
                         cannot start. Nothing else — no Nix in the project.

                         Currently: neburion/media-tracker (:8778) and
                         neburion/elden-ring-tracker (:8777), both pinned in
                         flake.lock, so `nixos-rebuild --rollback` takes the app
                         version back with the system generation.

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
cli/nixos-scripts/       one script per file — rebuild, rebuild-all, trebuild,
                         update, nixflash. lib.nix holds the shared shell
                         fragments (cloudFlake, pre-rebuild hook loop,
                         local-diverged warning, deploy_host); it is a plain
                         function, not a module.
cli/packager/            flatpak

desktop/wm/hyprland/     env, input, keybinds, looks, monitors, programs, session,
                         themes, screenshot-tools, hyprlock, auto-exec, enable,
                         window-rules
desktop/theming/gtk/     per-theme GTK packages + config/dconf/glib/css
desktop/theming/spotify* spicetify colours — spotify.nix (one color.ini section
                         per palette), spotify-glass.nix (fixed glass scheme +
                         user.css). Imported by the preset, not by apps/, because
                         spicetify bakes the scheme into the store path at build
                         time; apps/spotify.nix only installs the player.
desktop/cursor/          one file per pointer theme — adwaita.nix,
                         borealis.nix, breezex-black.nix (the last packages
                         an upstream release directly — pinned url+hash, needs
                         a manual bump). Each sets
                         home.pointerCursor (GTK + ~/.icons) and publishes
                         $cursorTheme/$cursorSize for wm/hyprland/env.nix.
                         Swapping the pointer is one import line in the preset.
desktop/clipboard/       wl-clipboard
desktop/terminal/        ghostty
desktop/tray-apps/       libnotify (nm-applet/blueman replaced by native quickshell widgets)
desktop/presets/         aggregator presets — glass.nix (translucent,
                         themeless, per-monitor wallpapers), clean.nix (sepia
                         terminal rice), simple.nix (plain quickshell),
                         hyprland-minimal.nix (waybar legacy/fallback)
desktop/bar/quickshell/  Bar, BarClock, BarWorkspaces, BarBattery, BarHardwareGroup,
                         BarTray, BarPowerToggle, BarWifi, BarBluetooth, Capsule widget
                         (each .nix owns its service singleton + widget; self-contained)
desktop/launcher/quickshell/  AppLauncher, ThemeSwitcher, PowerMenu
desktop/notifications/quickshell/  NotificationCenter
desktop/osd/quickshell/  OsdVolume, OsdBrightness (+ BrightnessState service)
desktop/wallpaper/quickshell/  WallpaperPicker (+ WallpaperState service)
desktop/quickshell-glass-shared/  glass-only shared layer, imported by every
                         quickshell-glass component (which pulls in
                         quickshell-shared/core.nix through it)
                           palette.nix — Common/Glass.qml, literal tokens, no
                                         ThemeState binding
                           surface.nix — Widgets/GlassSurface.qml
                           wallpaper-state.nix — Services/WallpaperState.qml,
                                         per-monitor path + accent from one
                                         watched wallpapers.json
                           accent.nix  — glass-accent / glass-wallpaper /
                                         glass-wallpaper-restore
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
- `displays.monitors` : attrs of `{ name; mode; position; scale; transform? }` — `transform` is optional and emitted by `mkMonitorLine` only when present. **`position` must be packed by *effective* width, i.e. the rotated width for anything declared with `transform` 1/3/5/7.** These lines are re-applied on every Hyprland config reload, so a declaration that disagrees with the resting orientation makes every rebuild visibly reshuffle the layout before `restore-monitor-transforms` corrects it.
- `gpu.prime.intelBusId` / `gpu.prime.nvidiaBusId` : str (PCI addresses)
- `gpu.openKernelModule` : bool (Turing+ default true, flip for Pascal)
- `gpu.externalMonitorOnDgpu` : bool (disables fine-grained runtime PM if true)
- `backlight.sysfsBrightnessPath` / `backlight.sysfsMaxBrightnessPath` : str (sysfs paths)

Displays and backlight are surfaced to home-manager via `flake.nix` (`hostConfig.displays.monitors`, `hostConfig.backlight`). GPU options are read by `modules/system/hardware/nvidia.nix`. Backlight options are read by `quickshell-shared/services/brightness-state.nix` (baked into QML at build time).

## Conventions cheat sheet

- `default.nix` in a directory = aggregator. Never has config.
- New app? Add `modules/home/apps/<name>.nix`, then add one import line to `users/neburion/home.nix`.
- New theme? Add `modules/home/themes/<name>.nix` (data only), then add it to `modules/home/themes/default.nix`.
- New host? Copy `hosts/pod042/` skeleton, minimize imports, put physical facts in `hardware-layout/`, add to `flake.nix` `nixosConfigurations`. Do NOT add `networking.hostName` — the flake injects it. Two steps land *after* first boot, not before: add the tailnet IP to `modules/system/networking/tailnet-hosts.nix` (nothing resolves the bare hostname until then), and commit the generated `hardware-configuration.nix`.
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

**The glass preset is the exception that proves the rule.** It provides `$statusBar`, `$appLauncher`, `$powerMenu` and `$wallpaperManager` exactly as above, but *not* `$themeSwitcher` — it has no themes. A variable that is never defined is not an error in hyprlang; the bind would just exec the literal string `$themeSwitcher`. Since `settings.bind` is a list and home-manager merges lists, a bind cannot be removed by an override, so `wm/hyprland-glass/keybinds.nix` is a fork of the base file with that one line deleted. **If you add a shell variable to `keybinds.nix`, every provider must supply it or fork the file.**

**Swap rule:** to replace quickshell with another shell, remove the quickshell import and add a new module that provides the same variables. `keybinds.nix` and `auto-exec.nix` update with zero changes.

This mirrors how `hardware-layout/` auto-configures monitors: the per-host environment module publishes facts, behavior modules consume them. Shell provider modules publish Hyprland variable facts; keybinds/exec consume them.

## The glass preset — themeless, per-monitor

`presets/glass.nix` is the first preset that opts out of the theme system
rather than participating in it, and the first where wallpaper is per-output.
Both are worth knowing before editing it.

**No themes is an import-list decision.** Nothing is disabled at runtime; four
modules are simply not imported — `launcher/…/theme-switcher.nix`,
`wm/hyprland/themes.nix`, `theming/gtk/theme-sync.nix`, and the per-theme GTK
packages. `quickshell-shared/core.nix` is untouched and still generates
`Common/Theme.qml` and `Services/ThemeState.qml`; the glass modules just never
import them, reading `Common/Glass.qml` (literal values) instead. That keeps
`clean` and `simple` working with zero risk. `base.nix` still imports
`desktop/theme-switcher`, so `theme-set` and the `themeHooks` option still
exist — under glass it just carries fewer hooks (fish, neovim, superfile; the
gtk/hyprland/hyprlock/ghostty hooks are gone with their modules). Spotify was
counted here until its `themeHook` was found to be dead — it called a
`spicetify` binary that is not installed — and its colours moved to
`theming/spotify-glass.nix`.

**The blur is Hyprland's, not Quickshell's.** A layer surface cannot read the
pixels behind it. Every glass panel is a transparent `PanelWindow` with a
translucent child; `wm/hyprland-glass/layer-rules.nix` matches the namespaces
those surfaces declare (`quickshell:bar`, `:popup`, `:launcher`,
`:notifications`, `:osd`) and applies `blur = on`. `wm/hyprland-glass/window-opacity.nix`
is the window-surface counterpart: Spotify is CEF on XWayland, so it has no
alpha channel to paint into and gets its translucency from an `opacity` rule
plus `decoration:blur:ignore_opacity`. That is also why its theme carries no
`backdrop-filter` — the compositor already runs the blur, and doing it inside
the renderer instead is what makes glassy spicetify themes stutter. **If a namespace ever
changes and the rule stops matching, the shell still runs and still looks
deliberate — just flat.** That is the failure mode to suspect when it looks
"wrong but fine". `ignore_alpha = 0.08` is what keeps the transparent margins
of the bar's 50px strip unblurred so only the inset panel is glass.

**The bar never overlaps a window.** The `PanelWindow` is full width with
`implicitHeight: 50`, which reserves a 50px exclusive zone; Hyprland shrinks
the tiling area to match (`hyprctl -j monitors` → `reserved: [0, 50, 0, 0]`).
Consequence worth stating: because windows cannot enter the zone, the glass is
mostly blurring *wallpaper*. Real content-blur only happens under fullscreen
windows, floating windows and the launcher scrim.

**Wallpapers are per monitor.** State is one JSON file keyed by output at
`~/.local/state/quickshell/wallpapers.json`:

```
{ "DP-1": { "path": "/…/x.jpg", "accent": "#A2C6E2" } }
```

`glass-wallpaper <monitor> <path>` applies it to that output only
(`awww img --outputs`, or `mpvpaper <output>` for animated files), derives the
accent and rewrites the file. `Services/WallpaperState.qml` watches it with a
single `FileView` — one file rather than one per monitor, because `FileView`
paths are static per instance and a file-per-monitor scheme would need an
`Instantiator` over `Quickshell.screens` to build them. `glass-wallpaper-restore`
replays the whole file on login, which is why `wm/hyprland-glass/auto-exec.nix`
is a fork: the base restores a single wallpaper to every output.

**The accent is the one thing that moves.** Each screen's bar reads
`WallpaperState.accentFor(screenName)`. The extractor keeps only the *hue* of
the most vibrant colour in the image and pins saturation to 52% and lightness
to 76% — a raw dominant colour is a near-black on most wallpapers, and even a
vivid one arrives at an arbitrary lightness that either vanishes against the
glass or shouts over it. Images with no saturated mid-tone (grids, star fields,
the NixOS logo) fall back to `#EDF0F5`; a greyscale wallpaper getting a white
accent is the intended answer, not a failure.

**The picker filters by orientation, not by category.** The library is
`~/Media/Wallpapers/<Orientation>/<Category>/`. Category is a filing system, so
the scan is recursive and everything lands in one flat carousel; orientation is
the part the shell can act on. Note it is derived from `ShellScreen`, not from
`HyprlandMonitor`: **`HyprlandMonitor` has no `transform` property, and its
`width`/`height` are the physical mode** — a rotated screen still reports
2560x1440 there. `ShellScreen` is rotation-aware, so the picker matches the
focused monitor by name against `Quickshell.screens` and asks whether that
screen is taller than it is wide.

**Qt 6.11 specifics the glass QML relies on.** `font.features` (6.6+) for
tabular figures, and `font.variableAxes` (6.7+) to drive the Material Symbols
`FILL` axis — active state is an animation along that axis rather than a colour
swap or a second glyph. Also: **`font.pixelSize` is an int.** Fractional values
fail at load with `Invalid property assignment: int expected`.

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

- `hosts/*/hardware-layout/wifi-layout.nix` — wifi PSK in plaintext, **intentionally**. Threat model requires attacker + physical proximity to the wifi + knowledge of the public repo simultaneously. Payoff = free wifi. Not worth the sops indirection.
- `users/server-admin/account.nix` — `initialPassword = "1234"` in plaintext. Deliberately trivial for headless server-class hosts (LAN-only + auth-gated CF tunnel); not a real secret. If ever elevated, switch to `hashedPasswordFile` fed by sops.

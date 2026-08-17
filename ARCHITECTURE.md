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
| `pod042`          | Main laptop; reading tracker over the Obsidian vault   | `limine`        | `neburion`          |
| `home-server`     | Headless family server: print/scan web UI              | `systemd-boot`  | `server-admin`      |
| `personal-server` | Headless personal server: Elden Ring tracker           | `systemd-boot`  | `server-admin`      |
| `installer`       | Live USB ISO                                           | isoImage output | (built via `iso/`)  |

`home-server` and `personal-server` are the same *class* of machine (old laptop,
headless, `server-admin`, always-on) split by *audience*: the family depends on
one, so it stays boring; the other is mine to break. Per the fleet principle
neither depends on the other — the split is about blast radius, not topology.
`personal-server` runs one service so far, the Elden Ring tracker: on the tailnet
at `http://personal-server:8777`, and publicly at `https://eldenring.azuresalt.app`
through a Cloudflare tunnel. It is the first host to expose something whose gate
is not solely a Cloudflare Access policy — the app carries HTTP Basic Auth from
the `elden-ring-password` sops secret and refuses to bind a non-loopback address
without it, so a missing Access policy weakens the gate rather than removing it.
Set the policy anyway.

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

elden-ring-tracker/      aggregator → service.nix (stdlib-Python SQLite tracker
                         + web UI on :8777; firewall opens the port on tailscale0
                         only, cloudflared reaches it via loopback. HTTP Basic
                         Auth from a sops secret via LoadCredential; refuses to
                         bind non-loopback without it. links.json declares an
                         implication graph so one boss tick settles its
                         achievement/Remembrance/Great Rune; seed.py runs as
                         ExecStartPre, migrates the DB in place, re-attaches
                         progress by natural key, and aborts on a bad link)

reading-tracker/         aggregator → service.nix (stdlib-Python web UI over the
                         Reading-Ob Obsidian vault on :8778, pod042 only). The
                         vault's markdown IS the database — no mirror, no seed.
                         Runs as `neburion` with ProtectHome off and the vault
                         as its only ReadWritePath, because the notes are that
                         user's files. Writes splice single frontmatter keys and
                         re-read before writing, so Obsidian can be open at the
                         same time; a field whose value did not change is never
                         written. Covers are cached under /var/lib, not
                         committed — they belong to the vault, not the repo.

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
desktop/clipboard/       wl-clipboard
desktop/terminal/        ghostty
desktop/tray-apps/       libnotify (nm-applet/blueman replaced by native quickshell widgets)
desktop/presets/         aggregator presets — clean.nix (sepia terminal
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

- `hosts/*/hardware-layout/wifi-layout.nix` — wifi PSK in plaintext, **intentionally**. Threat model requires attacker + physical proximity to the wifi + knowledge of the public repo simultaneously. Payoff = free wifi. Not worth the sops indirection.
- `users/server-admin/account.nix` — `initialPassword = "1234"` in plaintext. Deliberately trivial for headless server-class hosts (LAN-only + auth-gated CF tunnel); not a real secret. If ever elevated, switch to `hashedPasswordFile` fed by sops.

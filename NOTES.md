# NOTES

Lore. How subsystems actually work, what broke once, what to suspect when something
misbehaves. **Nothing here is binding** — the law is `DESIGN.md`.

---

## Deploying

**Test with `trebuild`, not `rebuild`.** The two read from different places, and this is
the single easiest way to think a change landed when it didn't:

| Script | Flake source | Sees uncommitted edits? |
|---|---|---|
| `trebuild` | `path:$HOME/NixOS` | **Yes** — local working tree |
| `rebuild` | `github:neburion/NixOS` | **No** — origin/master only |

`rebuild` only deploys work that is committed **and pushed**. Locally-committed edits are
as invisible as uncommitted ones. `trebuild` is a `test` activation — it dies on reboot.

`warnIfLocalDiverged` in the scripts' shared lib guards this: it checks a dirty working
tree (`git status --porcelain`) *and* unpushed commits (`git rev-list --count
'@{upstream}..HEAD'`), listing the offending files. It warns; it does not block — you may
knowingly redeploy the cloud version while carrying unrelated dev config.

Until 2026-08-15 it only checked the second condition, so a dirty tree scored 0 and passed
silently: `rebuild` printed a fresh store path and `Done.` while deploying the *cloud*
version — a wholly convincing success message for a no-op.

> **`Done.` is not proof.** Verify the generated artifact. `grep` the value you changed in
> `~/.config/hypr/hyprland.conf`, or read back the unit you expected to appear.

Every script reading a `github:` flake passes `--refresh` to bypass nix's 1-hour tarball
cache, so `git push && rebuild` does pick up the just-pushed commit. That means `rebuild`
and `nixflash`; `trebuild` reads the local tree and needs no flag. `nixflash` was the
exception until 2026-08-16 — it moved directories in `0f97cf0` without picking up the flag,
so `git push && nixflash` could build an ISO from the *previous* HEAD while printing an
entirely normal `Built: /nix/store/...` line.

**The recurring hazard of the cloud-flake design: when the source is remote, a convincing
success message tells you a build happened, never that it built what you just wrote.**

**Remote deploys.** `rebuild <hostname>` from any fleet workstation uses `nixos-rebuild
--target-host` over SSH — no rsync. Fleet SSH config maps hostnames to `server-admin` for
server-class hosts; passwordless wheel on servers means non-interactive activation.
`rebuild-all` does the whole fleet in one pass — remotes first, local host last, skipping
anything powered off, and one failure doesn't abort the rest. Both share `deploy_host` from
the scripts' lib, so their flags cannot drift apart.

---

## The fleet

| Host | Purpose | Boot | User |
|---|---|---|---|
| `pod042` | Main laptop | `limine` | `neburion` |
| `home-server` | Headless family server: print/scan web UI | `systemd-boot` | `server-admin` |
| `personal-server` | Headless personal server: trackers, paisa | `systemd-boot` | `server-admin` |
| `installer` | Live USB ISO | isoImage output | — |

Every host is on the fleet tailnet, so bare hostnames resolve via MagicDNS from anywhere
and `rebuild <host>` works regardless of the physical network the target sits on.

`home-server` and `personal-server` are the same *class* of machine (old laptop, headless,
always-on) split by *audience*: the family depends on one, so it stays boring; the other is
mine to break. Neither depends on the other — the split is about blast radius, not topology.

Two steps land **after** a new host's first boot, not before: add its tailnet address to
the tailnet-hosts module (nothing resolves the bare hostname until then), and commit the
generated hardware configuration. That second one bites specifically because `rebuild`
deploys from `github:` — a machine whose generated hardware config was never copied back
into the repo gets deployed a config describing someone else's disks. The **install** is
correct (the installer writes it into the repo copy and installs via `path:`); it's the
first `rebuild` afterwards that fails.

### The installer host

It deliberately bypasses `mkSystem`: no `specialArgs`, no home-manager, no overlays — so it
*cannot* import most system modules, which assume `inputs`. That's why it re-states the one
nix setting it needs instead of importing the shared module. You also build a different
attribute: `.config.system.build.isoImage`, not `.toplevel`. `nixflash` wraps that build
plus the `dd`. Its scripts are live-USB-only by nature and carry their own `runtimeInputs`.

---

## The app platform

Projects that live in their own repos, deployed here. A host names the repos in its policy;
each repo carries an `app.json` at its root declaring a port, its URLs, which secrets it
wants and whether it needs state. The platform turns that into a systemd unit, a system
user, `/var/lib/<name>`, `LoadCredential` wiring, the tailnet firewall rule and the
Cloudflare tunnel.

**The manifest is bounded, not obeyed.** Ports must sit in 8700–8799; hostnames under
`azuresalt.app`; secrets resolve to sops keys prefixed with the app's own name; the runtime
must be one of a known few; `run` may not contain shell metacharacters. A repo can only
ever reach its own password, and push access to it is not code execution here.

**Contract for an app:** listen on `$PORT`, keep durable things in `$STATE_DIR`, read
secrets from `$CREDENTIALS_DIRECTORY/<name>`, exit non-zero if it cannot start. Nothing
else — no Nix in the project.

Apps are pinned in `flake.lock`, so `nixos-rebuild --rollback` takes the app version back
with the system generation. Updating one is `nix flake update <name>`.

`paisa` is the exception, imported directly: it is a nixpkgs binary rather than a repo of
ours, so there is no `app.json` to read — only a unit and a state directory. It follows the
platform's shape by hand. It also carries `IPAddressDeny`, and note the **30-second Cost
Inflation Index stall** on first start if it can reach the internet.

The Elden Ring tracker and media tracker carry HTTP Basic Auth from sops and refuse to bind
a non-loopback address without it, so a missing Cloudflare Access policy weakens the gate
rather than removing it. Set the policy anyway.

---

## The glass preset

**The blur is Hyprland's, not Quickshell's.** A layer surface cannot read the pixels behind
it. Every glass panel is a transparent `PanelWindow` with a translucent child; the WM's
layer rules match the namespaces those surfaces declare (`quickshell:bar`, `:popup`,
`:launcher`, `:notifications`, `:osd`) and apply `blur = on`. Spotify is CEF on XWayland,
so it has no alpha channel to paint into and gets its translucency from an `opacity` rule
plus `decoration:blur:ignore_opacity` — which is also why its theme carries no
`backdrop-filter`: the compositor already runs the blur, and doing it inside the renderer
is what makes glassy spicetify themes stutter.

> **If a namespace changes and the rule stops matching, the shell still runs and still
> looks deliberate — just flat.** That is the failure mode to suspect when it looks
> "wrong but fine".

`ignore_alpha = 0.08` keeps the transparent margins of the bar's 50px strip unblurred, so
only the inset panel is glass.

**The bar never overlaps a window.** Full width, `implicitHeight: 50`, which reserves a 50px
exclusive zone (`hyprctl -j monitors` → `reserved: [0, 50, 0, 0]`). Consequence: the glass
is mostly blurring *wallpaper*. Real content-blur only happens under fullscreen windows,
floating windows and the launcher scrim.

**Wallpapers are per monitor.** One JSON file keyed by output at
`~/.local/state/quickshell/wallpapers.json`:

```
{ "DP-1": { "path": "/…/x.jpg", "accent": "#A2C6E2" } }
```

`glass-wallpaper <monitor> <path>` applies it to that output only (`awww img --outputs`, or
`mpvpaper <output>` for animated files), derives the accent and rewrites the file. One
`FileView` watches it — one file rather than one per monitor, because `FileView` paths are
static per instance and a file-per-monitor scheme would need an `Instantiator` over
`Quickshell.screens`. `glass-wallpaper-restore` replays the whole file on login.

**The accent is the one thing that moves.** The extractor keeps only the *hue* of the most
vibrant colour and pins saturation to 52% and lightness to 76% — a raw dominant colour is a
near-black on most wallpapers, and even a vivid one arrives at an arbitrary lightness that
either vanishes against the glass or shouts over it. Images with no saturated mid-tone
(grids, star fields, the NixOS logo) fall back to `#EDF0F5`; a greyscale wallpaper getting
a white accent is the intended answer, not a failure.

**The picker filters by orientation, not category.** The library is
`~/Media/Wallpapers/<Orientation>/<Category>/`; category is a filing system, so the scan is
recursive and everything lands in one flat carousel. Orientation is derived from
`ShellScreen`, **not** `HyprlandMonitor`: `HyprlandMonitor` has no `transform` property and
its `width`/`height` are the physical mode, so a rotated screen still reports 2560x1440
there. `ShellScreen` is rotation-aware.

**Qt 6.11 specifics the glass QML relies on:** `font.features` (6.6+) for tabular figures,
and `font.variableAxes` (6.7+) to drive the Material Symbols `FILL` axis — active state is
an animation along that axis rather than a colour swap or a second glyph. Also
**`font.pixelSize` is an int**; fractional values fail at load with `Invalid property
assignment: int expected`.

---

## Quickshell registry — the `lines` footgun

The registry option is typed `lines`, which **merges by concatenation, not by conflict**.
Two modules registering the same key (two presets each defining
`services.WallpaperState`) do not error — their QML is glued end to end into one file with
two `pragma Singleton` blocks, and quickshell fails at load with a syntax error pointing at
the seam.

This is the origin of **L4** in `DESIGN.md`, and half the reason the shared quickshell layer
is being dissolved.

---

## Shell auto-wiring

Hyprland keybinds and exec-once entries use shell variables — `$statusBar`, `$appLauncher`,
`$wallpaperManager`, `$themeSwitcher`, `$powerMenu` — that are **never set in those files**.
Whichever provider module is imported contributes its own.

Consequence: importing a preset automatically wires exec-once and every keybind without
touching `keybinds.nix` or `auto-exec.nix`. Swapping a bar is one import line.

**The glass preset is the exception that proves the rule.** It provides everything except
`$themeSwitcher` — it has no themes. A variable that is never defined is not an error in
hyprlang; the bind would just exec the literal string `$themeSwitcher`. Since
`settings.bind` is a list and home-manager merges lists, a bind cannot be removed by an
override — so glass's `keybinds.nix` is a fork of the base file with that one line deleted.

> **If you add a shell variable to `keybinds.nix`, every provider must supply it or fork
> the file.**

---

## Displays

`displays.monitors` entries are `{ name; mode; position; scale; transform? }`.

> **`position` must be packed by *effective* width** — the rotated width for anything
> declared with `transform` 1/3/5/7.

These lines are re-applied on every Hyprland config reload, so a declaration that disagrees
with the resting orientation makes every rebuild visibly reshuffle the layout before
`restore-monitor-transforms` corrects it.

---

## Secrets

Encrypted secrets live in `secrets/*.yaml`, one file per host, matched by
`sops.defaultSopsFile` computed from the hostname. Every secret is encrypted to a **single
fleet-wide age recipient**. Consequence: any host holding the private key can decrypt every
secret — an intentional single-fleet trust boundary. Don't add low-trust hosts.

**Key material**

- `secrets/age-key.enc` — the age *private* key, encrypted at rest with a passphrase
  (openssl AES-256-CBC + PBKDF2, 600k iters). Committed. Safe to publish only insofar as
  the passphrase is strong. The passphrase lives in KeePassXC.
- `/var/lib/sops-nix/key.txt` — plaintext age key on each host, mode 0400 root:root.
  sops-nix reads it at activation to decrypt into `/run/secrets/<name>`.

**How a host gets it.** Fresh install: the installer script prompts for the passphrase,
decrypts via `openssl enc -d`, and writes `/mnt/var/lib/sops-nix/key.txt` before
`nixos-install` — wrong passphrase bails *before* the disk wipe. Existing host: decrypt on
any dev machine and `sudo install -Dm400 - /var/lib/sops-nix/key.txt`.

**Rotating the passphrase** (routine hygiene — no host changes needed, the keypair is
unchanged and only its at-rest envelope moves):

```
openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in secrets/age-key.enc -pass pass:OLD | \
openssl enc    -aes-256-cbc -pbkdf2 -iter 600000 -salt -out secrets/age-key.enc.new -pass pass:NEW
mv secrets/age-key.enc.new secrets/age-key.enc
```

**Rotating the keypair** (only if the key leaks): generate a new pair, update `.sops.yaml`,
`sops updatekeys secrets/*.yaml`, re-encrypt the private key, redistribute
`/var/lib/sops-nix/key.txt` to every host, rebuild each.

---

## Accepted debt

Both of these are decisions, not oversights. Don't "fix" them without a reason.

- **Wifi PSK in plaintext** in each host's hardware layout. The threat model requires an
  attacker with physical proximity *and* knowledge of the public repo simultaneously.
  Payoff: free wifi. Not worth the sops indirection.
- **`server-admin` bootstrap password in plaintext.** Deliberately trivial for headless
  server-class hosts (LAN-only plus an auth-gated tunnel). If ever elevated, switch to
  `hashedPasswordFile` fed by sops.

---

## Deferred decisions

- **Lock screen stays hyprlock.** Quickshell's `SessionLock` implements
  `ext-session-lock-v1`, but PAM authentication needs either a native binding (doesn't
  exist) or a custom PAM helper with secure IPC — complexity not worth it when hyprlock
  already looks right and is the security-critical path.
- **pod042 jack detection.** ALC256 on the ASUS FX507VV4 has no upstream quirk for subsys
  `0x104314a3`. The jack works; WirePlumber just can't auto-route to it.
- **pod042 `nvidia_uvm` after Windows.** Booting Linux after Windows can fail to load
  `nvidia_uvm`; `vkCreateDevice` then dies and every Proton game exits in ~5s. Fix:
  `modprobe nvidia_uvm`.

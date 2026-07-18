# Unit-3 Preset Port — Build Plan

Port of [samyns/Unit-3](https://github.com/samyns/Unit-3) (MIT, Hyprland + Waybar + Quickshell widgets, NieR:Automata aesthetic) into this repo as a **drop-in preset**. Swapping between the current `hyprland-quickshell` preset and the new `hyprland-unit3` preset is one line in `users/neburion/home.nix` followed by `sudo nixos-rebuild switch --flake path:$HOME/NixOS#pod042`.

**Prerequisite reading**: `ARCHITECTURE.md` (Manifest + Additive philosophy, Shell auto-wiring rules). Do not violate the layer rules.

---

## Confirmed design decisions

| # | Decision | Choice |
|---|----------|--------|
| 1 | Terminal | **Kitty**, ported 1:1 from Unit-3's `config/kitty/kitty.conf` (NieR palette, Share Tech Mono, cursor trail). New module `modules/home/desktop/terminal/kitty-unit3.nix`. |
| 2 | Binary assets (nier-arrow.png, wallpapers) | **Vendor into the repo** under `modules/home/desktop/quickshell-unit3/assets/`. No `fetchFromGitHub`. |
| 3 | Hyprlock animated background | **Skip.** Use a static NieR wallpaper. No python3 / cairo / numpy / pillow / opencv deps. |
| 4 | Companions widget (2b.gif / amazon.gif / mai.gif animated characters) | **Skip entirely.** Do not port `Companions.qml`, do not vendor the gifs, drop the `companionsEnabled` Setting. |

---

## Target module tree (all new files)

```
modules/home/desktop/
  presets/hyprland-unit3.nix                  ← the swap point

  wm/hyprland-unit3/
    default.nix                               (aggregator; imports YOUR keybinds unchanged)
    looks.nix                                 (sepia borders, niercurve, gaps 4/8, no rounding/blur)
    window-rules.nix                          (quickshell float+pin, spotify special, yazi picker)
    hyprlock.nix                              (NieR-styled hyprlock, static bg)
    extra-binds.nix                           (adds SUPER+Tab → ControlCenter; nothing else)

  bar/waybar-unit3/
    default.nix                               (provides $statusBar = "waybar")
    config.nix                                (workspaces/window/ticker/cpu/mem/net/audio/clock/power)
    style.nix                                 (sepia CSS)
    scripts/pomodoro.nix                      (pomodoro.sh + pomodoro_toggle.sh via writeShellScriptBin)

  quickshell-unit3/
    default.nix                               (aggregator, contributes Hyprland vars, exec-once)
    theme.nix                                 → Common/Unit3Theme.qml   (sepia palette baked; singleton)
    settings.nix                              → Common/Unit3Settings.qml (scale, player pos, etc.)
    components.nix                            → Widgets/{CornerDeco,NierButton,Scanlines,WipeCurtain}.qml
    control-center.nix                        → Modules/ControlCenter.qml + `ctrl` IPC
    menu.nix                                  → Modules/Unit3Menu.qml (Super_L tap-launcher)
    player.nix                                → Modules/Unit3Player.qml (MPRIS via playerctl)
    volume-bar.nix                            → Modules/Unit3VolumeBar.qml (audio OSD)
    notifications.nix                         → Modules/Unit3Notifications.qml (notification daemon)
    wallpaper-picker.nix                      → Modules/Unit3WallpaperPicker.qml + `unit3wall` IPC
    scripts.nix                               (active-monitor.sh, list-apps.sh, etc.)
    assets/                                   (vendored: nier-arrow.png + wallpapers)
    assets.nix                                (installs vendored files into ~/.config/quickshell/assets/)

  terminal/kitty-unit3.nix                    (Kitty config, provides $terminal = "kitty")
```

---

## The preset file

```nix
# modules/home/desktop/presets/hyprland-unit3.nix
{ ... }:

# NieR:Automata aesthetic, ported from samyns/Unit-3.
# Swap ../wm/hyprland → ../wm/hyprland-unit3 for the NieR look;
# swap ../bar/quickshell → ../bar/waybar-unit3 for the Unit-3 Waybar.
# Individual modules can be recombined freely — no cross-coupling.

{
  imports = [
    ../wm/hyprland-unit3
    ../bar/waybar-unit3
    ../quickshell-unit3
    ../tray-apps
    ../clipboard/wl-clipboard.nix
    ../terminal/kitty-unit3.nix
    ../theming/gtk
  ];
}
```

**User-facing swap** in `users/neburion/home.nix`:

```diff
- ../../modules/home/desktop/presets/hyprland-quickshell.nix
+ ../../modules/home/desktop/presets/hyprland-unit3.nix
```

That's the only line the user touches to move between environments.

---

## Keybinds — reuse `wm/hyprland/keybinds.nix` unchanged

Your existing keybinds use shell vars. The Unit-3 modules **provide** those vars pointing at Unit-3 primitives. Because the vars are the contract, `keybinds.nix` does not change.

| Var | Provider | Value under Unit-3 |
|-----|----------|--------------------|
| `$statusBar` | `bar/waybar-unit3/default.nix` | `waybar` |
| `$terminal` | `terminal/kitty-unit3.nix` | `kitty` |
| `$appLauncher` | `quickshell-unit3/menu.nix` | `sh -c 'echo t >> /tmp/qs-menu'` |
| `$wallpaperManager` | `quickshell-unit3/wallpaper-picker.nix` | `qs ipc call unit3wall toggle` (add IPC handler to the QML) |
| `$themeSwitcher` | `quickshell-unit3/control-center.nix` | `qs ipc call ctrl toggle` (subsumed by ControlCenter) |
| `$powerMenu` | `quickshell-unit3/control-center.nix` | `qs ipc call ctrl toggle` (subsumed by ControlCenter) |
| `$fileManager`, `$audioManager`, `$taskManager`, `$webBrowser`, `$notesApp`, `$messenger`, `$discord`, `$musicPlayer`, `$gameLauncher`, `$steamLauncher`, `$localSend` | Existing user modules (nautilus, pavucontrol, btop, zen-browser, obsidian, signal, vesktop, spotify, heroic, steam, localsend) | Unchanged — the Unit-3 preset does not touch these. |
| `$locker` | `wm/hyprland-unit3/hyprlock.nix` | `hyprlock` |

`wm/hyprland-unit3/extra-binds.nix` **adds** (not replaces):

```
"SUPER, Tab, exec, qs ipc call ctrl toggle"
```

That is Unit-3's signature bind. Do not remove or reorder any of the existing binds.

---

## `wm/hyprland-unit3/default.nix` template

```nix
{ ... }:

# NieR-styled Hyprland preset. Reuses YOUR existing input/env/monitors/session/
# programs/screenshot-tools/themes/enable/auto-exec/keybinds verbatim.
# Only the visual layer (looks.nix), window rules, hyprlock styling, and
# the single extra SUPER+Tab bind are Unit-3-specific.

{
  imports = [
    ../hyprland/enable.nix
    ../hyprland/env.nix
    ../hyprland/input.nix
    ../hyprland/keybinds.nix          # ← YOUR keybinds, verbatim
    ../hyprland/monitors.nix
    ../hyprland/session.nix
    ../hyprland/programs.nix
    ../hyprland/screenshot-tools.nix
    ../hyprland/themes.nix
    ../hyprland/auto-exec.nix

    ./looks.nix
    ./window-rules.nix
    ./hyprlock.nix
    ./extra-binds.nix
  ];
}
```

---

## `wm/hyprland-unit3/looks.nix` (port from Unit-3 hyprland.conf)

```nix
{ ... }:
{
  wayland.windowManager.hyprland.settings = {
    general = {
      gaps_in            = 4;
      gaps_out           = 8;
      border_size        = 1;
      "col.active_border"   = "rgba(c8b89aee)";
      "col.inactive_border" = "rgba(1a1814aa)";
      layout             = "dwindle";
    };
    decoration = {
      rounding = 0;
      blur.enabled   = false;
      shadow.enabled = false;
    };
    animations = {
      enabled = true;
      bezier    = [ "niercurve, 0.4, 0, 0.2, 1" ];
      animation = [
        "windows,    1, 4, niercurve, slide"
        "windowsOut, 1, 3, niercurve, slide"
        "fade,       1, 4, niercurve"
        "workspaces, 1, 5, niercurve, slidevert"
      ];
    };
    dwindle.preserve_split = true;
    master = { new_status = "master"; mfact = 0.55; };
  };
}
```

## `wm/hyprland-unit3/window-rules.nix`

```nix
{ ... }:
{
  wayland.windowManager.hyprland.settings.windowrule = [
    "float on,     class:^(quickshell)$"
    "pin on,       class:^(quickshell)$"
    "noblur on,    class:^(quickshell)$"
    "noshadow on,  class:^(quickshell)$"
    "workspace special:spotify, class:^(Spotify)$"
    "fullscreen on,             class:^(Spotify)$"
    "float on,     class:^(qs-yazi-picker)$"
    "size 900 600, class:^(qs-yazi-picker)$"
    "center 1,     class:^(qs-yazi-picker)$"
  ];
}
```

## `wm/hyprland-unit3/extra-binds.nix`

```nix
{ ... }:
{
  wayland.windowManager.hyprland.settings.bind = [
    "SUPER, Tab, exec, qs ipc call ctrl toggle"
  ];
}
```

## `wm/hyprland-unit3/hyprlock.nix`

Port the `config/hypr/hyprlock.conf` from Unit-3 into home-manager's `programs.hyprlock.settings` form. Preserve **exactly**: sepia dot/outline colors, Share Tech Mono labels, Japanese subtitle (`ユニット · アクティブ`), corner info blocks (SESSION LOCKED, kernel, ARCH LINUX + lspci VGA), bottom ticker. Replace `path = ~/.config/hypr/lockbg.png` with a path to a vendored static wallpaper (drop `lock.sh`, `gen-lockbg.py`, `pixel_wave.py`, and all python deps — see decision #3).

---

## `bar/waybar-unit3/` — port from `config/waybar/`

### `default.nix`

```nix
{ ... }:
{
  imports = [ ./config.nix ./style.nix ./scripts/pomodoro.nix ];

  # Auto-wire var — see ARCHITECTURE.md "Shell auto-wiring"
  wayland.windowManager.hyprland.settings."$statusBar" = "waybar";

  programs.waybar.enable = true;
}
```

### `config.nix` — modules exactly matching Unit-3

- `modules-left`:   `hyprland/workspaces`, `hyprland/window`
- `modules-center`: `custom/ticker` (the katakana ticker: `接続中 // SCANNING // データ処理 // SYS:ACTIVE // NR-2B@ARCH // 全システム正常 // 起動完了 //`)
- `modules-right`:  `custom/pomodoro`, `cpu`, `memory`, `network`, `pulseaudio`, `clock`, `custom/power`

Position `top`, height 28. Full JSONC in `config/waybar/config.jsonc` upstream.

### `style.nix` — sepia CSS

Port `config/waybar/style.css` verbatim (Share Tech Mono, sepia `#c8b89a` fg on `rgba(11,10,9,0.92)` bg, per-module accent colors: cpu `#c87060`, memory `#6090c8`, network `#60a880`, pulseaudio `#c8a860`, power `rgba(200,96,96,0.5)`).

### `scripts/pomodoro.nix`

`writeShellScriptBin` for `pomodoro.sh` and `pomodoro_toggle.sh`. Install via `home.packages`. Reference from the `custom/pomodoro` module using the absolute Nix store path.

---

## `quickshell-unit3/` — how to hook into the existing registry

The existing `modules/home/desktop/quickshell/registry.nix` exposes `options.quickshell.{services, commons, modules, widgets, moduleInstantiations, shellExtraImports}` and `shell.nix` materializes them into `~/.config/quickshell/main/`. **Reuse it.** Each Unit-3 module contributes via `config.quickshell.*`. This preserves the Manifest + Additive rule ("Behavior modules never expose user-facing options").

**Naming**: prefix all Unit-3 QML component names with `Unit3` (e.g. `Unit3Menu`, `Unit3Player`) so they never collide with future components in your main preset. Exception: `ControlCenter` and `WipeCurtain` are Unit-3-only — no prefix needed but do namespace file paths.

### `quickshell-unit3/default.nix`

```nix
{ ... }:
{
  imports = [
    ../quickshell                        # brings in core.nix (registry, shell.nix, package)
    ./theme.nix
    ./settings.nix
    ./components.nix
    ./control-center.nix
    ./menu.nix
    ./player.nix
    ./volume-bar.nix
    ./notifications.nix
    ./wallpaper-picker.nix
    ./scripts.nix
    ./assets.nix
  ];
}
```

### Contribution pattern per module

Each Unit-3 component `.nix` writes its QML into the registry. Example skeleton for `menu.nix`:

```nix
{ ... }:
{
  quickshell.modules."Unit3Menu" = ''
    import Quickshell
    import Quickshell.Io
    import Quickshell.Wayland
    import QtQuick
    import "../Common"
    import "../Widgets"

    // ... full Menu.qml body from upstream ...
  '';

  quickshell.moduleInstantiations = [ "Unit3Menu {}" ];

  # $appLauncher var (Shell auto-wiring)
  wayland.windowManager.hyprland.settings."$appLauncher" =
    "sh -c 'echo t >> /tmp/qs-menu'";
}
```

Same shape for every module. Full QML source is upstream at `config/quickshell/{shell.qml,widgets/*.qml,components/*.qml,theme/Theme.qml,settings/Settings.qml}`.

### File-by-file upstream mapping

| Nix module | Contributes | Upstream source |
|------------|-------------|-----------------|
| `theme.nix` | `commons."Unit3Theme"` | `config/quickshell/theme/Theme.qml` |
| `settings.nix` | `commons."Unit3Settings"` | `config/quickshell/settings/Settings.qml` (drop `companionsEnabled/companionsMarginRight/companionsSpriteSize`) |
| `components.nix` | `widgets."CornerDeco"`, `widgets."NierButton"`, `widgets."Scanlines"`, `widgets."WipeCurtain"` | `config/quickshell/components/*.qml` |
| `control-center.nix` | `modules."ControlCenter"` + `moduleInstantiations += "ControlCenter {}"` + IPC target `ctrl` | `config/quickshell/widgets/ControlCenter.qml` (~113 KB) |
| `menu.nix` | `modules."Unit3Menu"` + instantiation + `$appLauncher` var | `config/quickshell/widgets/Menu.qml` (~32 KB) + `config/quickshell/shell.qml` menu wiring |
| `player.nix` | `modules."Unit3Player"` + instantiation + `$musicPlayer` toggle bind (extra-binds) | `config/quickshell/widgets/Player.qml` (~40 KB) |
| `volume-bar.nix` | `modules."Unit3VolumeBar"` + instantiation | `config/quickshell/widgets/VolumeBar.qml` |
| `notifications.nix` | `modules."Unit3Notifications"` + instantiation | `config/quickshell/widgets/Notifications.qml` |
| `wallpaper-picker.nix` | `modules."Unit3WallpaperPicker"` + IPC `unit3wall` + `$wallpaperManager` var | `config/quickshell/widgets/WallpaperPicker.qml` |
| `scripts.nix` | `xdg.configFile` entries for `quickshell/scripts/{active-monitor.sh, list-apps.sh}` | `config/quickshell/{active-monitor.sh, list-apps.sh, setwallpaper.sh, wallpaper.sh}` |
| `assets.nix` | `xdg.configFile` entries copying vendored files into `~/.config/quickshell/assets/` | See "Vendored assets" below |

### Exec-once wiring

`quickshell-unit3/default.nix` should add to `exec-once`:

```
"pkill dunst || true"
"pkill mako || true"
"pkill swaync || true"
"udiskie &"
```

The main `qs` process is already started by `$statusBar` for the current preset — wait, **no**: under Unit-3 the bar is Waybar (`$statusBar = "waybar"`). Quickshell must be launched separately. Add:

```
"env QT_MEDIA_BACKEND=ffmpeg qs"
```

to `exec-once` in `quickshell-unit3/default.nix`.

### Deprecated hyprlock lock-flow

The upstream `lock.sh` regenerates `~/.config/hypr/lockbg.png` before invoking hyprlock. **Skip.** Under decision #3, we point hyprlock directly at a static wallpaper — no wrapper script needed. `$locker = "hyprlock"` in your existing `wm/hyprland/programs.nix` still works.

---

## Vendored assets

Copy these files from the upstream repo into the tree at their listed paths (they are checked in, no `fetchFromGitHub`).

| Vendored path | Upstream source | Purpose |
|---------------|-----------------|---------|
| `modules/home/desktop/quickshell-unit3/assets/nier-arrow.png` | `config/quickshell/assets/nier-arrow.png` | ControlCenter chevron |
| `modules/home/desktop/quickshell-unit3/assets/wallpapers/UDqXyQq.jpeg` | `assets/wallpapers/UDqXyQq.jpeg` | Default NieR wallpaper |
| `modules/home/desktop/quickshell-unit3/assets/wallpapers/2b.jpg` | `assets/wallpapers/video-games-nier-automata-2b-...jpg` (rename) | 2B wallpaper |
| `modules/home/desktop/quickshell-unit3/assets/wallpapers/hollow-knight.jpg` | `assets/wallpapers/vincent-bisschop-hollow-knight-...jpg` (rename) | Alternative wallpaper |
| `modules/home/desktop/quickshell-unit3/assets/wallpapers/nier-city.jpg` | `assets/wallpapers/wallpaperflare.com_wallpaper.jpg` (rename) | Alternative wallpaper |

**Do NOT vendor**: `assets/2b.gif`, `assets/amazon.gif`, `assets/mai.gif` (decision #4 — companions dropped).

`assets.nix` installs via `home.file` or `xdg.configFile` (whichever the QML expects). ControlCenter reads `assets/nier-arrow.png` relative to shell.qml → install at `~/.config/quickshell/main/assets/nier-arrow.png` (adjust the QML import path if the upstream used `../assets/`).

Hyprlock's `background.path` under decision #3 points at one of the vendored wallpapers (default: `UDqXyQq.jpeg`).

---

## `terminal/kitty-unit3.nix`

```nix
{ ... }:
{
  programs.kitty = {
    enable = true;
    font.name = "Share Tech Mono";
    font.size = 12;
    settings = {
      # Full body from Unit-3 config/kitty/kitty.conf — sepia palette, cursor
      # trail, letter_spacing 0.5, line_height 1.2, opacity 0.92,
      # window_padding_width 20, tab_bar_style hidden, all color0..color15,
      # cursor + cursor_trail + cursor_text_color, url styling.
    };
  };

  wayland.windowManager.hyprland.settings."$terminal" = "kitty";
}
```

---

## System-level deps to add

**In `hosts/pod042/configuration.nix`** (or an existing NixOS module you import there):

```nix
security.pam.services.qs-lock = { }; # only if any QML calls pamtester; else drop
environment.systemPackages = with pkgs; [ pamtester ]; # only if kept
```

Under decision #3 there is **no Python lockscreen bg** and under the deferred-lockscreen decision (see ARCHITECTURE.md) Quickshell is not the locker — hyprlock is. `pamtester` and `qs-lock` PAM entry are therefore **not needed**. Skip them.

**In `users/neburion/home.nix` behavior modules** (via `home.packages` where they belong):

- `kdeconnect` — required by ControlCenter's Quickshare panel (add if you want that panel; ControlCenter will show an "install KDE Connect" fallback if missing, so it's safe to omit initially)
- `figlet` — used by kitty greeter in Unit-3? verify by grepping upstream configs; skip if unused
- `yazi` — required by ControlCenter file picker for Quickshare
- `slurp`, `grim`, `hyprshot`, `satty` — already in `wm/hyprland/screenshot-tools.nix` (verify all four are present; add any missing)
- `awww` — already installed for your current preset (verified via `auto-exec.nix` line 8)
- `playerctl` — required by Player widget. Add explicitly.
- `qrencode`, `cloudflared` — Quickshare only; skip unless kdeconnect is enabled

**Fonts** — add to `modules/home/cli/fonts.nix` (or a new `fonts/unit3.nix` under home):

- `share-tech-mono` (from `pkgs.google-fonts` override, or fetch `.ttf` via `pkgs.fetchurl` and package via `runCommand`)
- `noto-fonts-cjk-sans` — required for the katakana ticker + hyprlock Japanese subtitle
- `noto-fonts-emoji` — usually already present via base

---

## Build order (phased — test after each phase)

1. **Phase 0 — scaffolding.** Create the empty preset file `hyprland-unit3.nix` pointing at empty stub modules. Rebuild — must succeed with no visible change while still using `hyprland-quickshell.nix` in `home.nix`.
2. **Phase 1 — wm/hyprland-unit3.** Full port of `looks.nix`, `window-rules.nix`, `extra-binds.nix`, `hyprlock.nix`. Import path stays `hyprland-quickshell` in `home.nix`; verify Nix eval alone.
3. **Phase 2 — bar/waybar-unit3.** Port config + style + pomodoro scripts. Standalone-testable by temporarily swapping the preset.
4. **Phase 3 — quickshell-unit3 skeleton.** Add `theme.nix`, `settings.nix`, `components.nix`. QML compiles.
5. **Phase 4 — quickshell-unit3 widgets.** Port `Unit3Menu`, `Unit3Player`, `Unit3VolumeBar`, `Unit3Notifications`, `Unit3WallpaperPicker`. Wire Hyprland vars.
6. **Phase 5 — ControlCenter.** Largest module (~113 KB QML). Port last. Verify `qs ipc call ctrl toggle` works before wiring SUPER+Tab.
7. **Phase 6 — terminal/kitty-unit3.** Port kitty.conf.
8. **Phase 7 — vendored assets.** Add binary files, wire via `xdg.configFile`.
9. **Phase 8 — flip the preset.** Change one line in `users/neburion/home.nix`, rebuild, verify golden path: login → bar visible → SUPER+Space (menu) → SUPER+Tab (ControlCenter) → SUPER+W (wallpaper picker) → SUPER+Escape (hyprlock) → unlock → SUPER+Return (terminal, kitty with NieR palette).
10. **Phase 9 — regression test.** Flip back to `hyprland-quickshell.nix`, rebuild, verify original preset intact.

Test command every phase (per `ARCHITECTURE.md` operating rules): `sudo nixos-rebuild switch --flake path:$HOME/NixOS#pod042`. Never `github:...` — hardware-configuration.nix is a placeholder locally.

---

## Verification checklist (phase 8)

- [ ] Waybar renders top-bar with sepia palette, katakana ticker in center
- [ ] SUPER+Space → app menu opens (Unit3Menu), typing filters, Enter launches
- [ ] SUPER+Tab → ControlCenter radial menu opens, WASD navigation works, Wi-Fi/BT/Audio panels functional
- [ ] SUPER+W → WallpaperPicker opens, selecting a wallpaper calls `awww img`
- [ ] Volume keys → Unit3VolumeBar OSD appears
- [ ] Notifications route through Unit3Notifications (verify `notify-send test` produces a NieR-styled popup, not the previous quickshell one)
- [ ] SUPER+Return → kitty spawns with NieR palette, cursor trail, Share Tech Mono
- [ ] SUPER+Escape → hyprlock with sepia labels, Japanese subtitle, corner info, static wallpaper
- [ ] Player widget toggles cleanly; playerctl controls work
- [ ] All existing keybinds ($fileManager, $webBrowser, $discord, etc.) still work unchanged

---

## Known limitations (document, do not fix)

1. **No theme switching under Unit-3.** Palette is hardcoded sepia in `Unit3Theme.qml` and `Unit3Settings.qml`. This is inherent to the upstream design. Users wanting theme-switchable UI stay on `hyprland-quickshell`.
2. **No animated hyprlock background** (decision #3). Static wallpaper only.
3. **No Companions widget** (decision #4). ControlCenter, Player, Menu, etc. all fully functional.
4. **`Companions.qml`, `2b.gif`, `amazon.gif`, `mai.gif`, and `companionsEnabled` setting are not ported** — do not attempt to add them without a fresh decision from the user.

---

## Files that must NOT be touched

Per ARCHITECTURE.md rules — the current preset must remain 100% intact after this port so swapping back is trivial:

- Everything under `modules/home/desktop/wm/hyprland/` (the current, non-unit3 hyprland module)
- Everything under `modules/home/desktop/bar/quickshell/`
- Everything under `modules/home/desktop/launcher/quickshell/`
- Everything under `modules/home/desktop/notifications/quickshell/`
- Everything under `modules/home/desktop/osd/quickshell/`
- Everything under `modules/home/desktop/wallpaper/quickshell/`
- `modules/home/desktop/presets/hyprland-quickshell.nix`
- `modules/home/desktop/presets/hyprland-waybar.nix`
- `modules/home/desktop/quickshell/` core (registry, shell, package, theme-sync, themes) — the Unit-3 preset **reuses** the registry infrastructure; do not modify it.
- `modules/home/desktop/wm/hyprland/keybinds.nix` — the whole point of the shell-var contract is that this file works untouched under both presets.

If you find yourself modifying any of the above during the port, stop and reconsider — the port is going wrong.

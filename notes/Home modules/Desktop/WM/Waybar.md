# Waybar

`home-modules/desktop/wm/waybar/`.

```
waybar/
├── default.nix      enables waybar + generates per-theme .css files + imports scripts
├── config.nix       module layout (modules-{left,center,right,group/hardware})
├── style.nix        the actual CSS string (imports @import for theme)
└── scripts/         power-toggle, current-power
```

## Bar layout (`config.nix`)

- **left** — clock, custom/power-toggle
- **center** — `hyprland/workspaces`
- **right** — tray, group/hardware

`group/hardware` (horizontal): pulseaudio, custom/gpu, memory, cpu, battery.

### Modules

| Module | Notes |
|---|---|
| `clock` | `{:%a %d %b - %I:%M %p}` |
| `custom/power-toggle` | Runs `~/.config/waybar/scripts/current-power.sh` every 10 s for display; `power-toggle.sh` on click — cycles performance → power-saver → balanced |
| `hyprland/workspaces` | Icons: ` `/` `/` ` (active/default/empty). Persistent: 1-5 on `eDP-1`, 6-10 on `HDMI-A-1` (TODO: derive from `hostConfig.displays.monitors`) |
| `tray` | spacing 10 |
| `pulseaudio` | scroll to adjust (5 step, max 150), click → pavucontrol |
| `custom/gpu` | `nvidia-smi --query-gpu=utilization.gpu …` |
| `memory` | critical at 80% |
| `cpu` | critical at 90% |
| `battery` | 10-step icon ramp (% 10/20/…/100) |

## Theme integration (`default.nix`)

For each palette in `themes`, generates `~/.config/waybar/themes/<name>.css` with `@define-color` rules for background, capsule, text, selection. The waybar style imports `themes/active.css` at the top — the active symlink is owned by `wofi-theme-switcher`.

The `style.nix` file is a plain Nix string (not a function) consumed by `default.nix` via `import`.

## Scripts (`scripts/`)

Both write a file to `~/.config/waybar/scripts/` (not packaged binaries). They use `${pkgs.power-profiles-daemon}/bin/powerprofilesctl` directly.

- `current-power.sh` — prints icon + label for current profile
- `power-toggle.sh` — cycles profile (performance → power-saver → balanced → performance)

## See also

- [[Modules/Hardware]] — `power-profiles.nix` provides `powerprofilesctl`
- [[Concepts/Theme switching]] — how `active.css` symlink is updated

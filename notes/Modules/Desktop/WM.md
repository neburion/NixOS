# Desktop — WM

`modules/desktop/wm/` — display server + login + wayland env.

| File | What it does |
|---|---|
| `hyprland.nix` | `programs.hyprland.enable = true` + xwayland |
| `sddm.nix` | Custom `sddm-nyx-theme` (assets copied from `sddm-astronaut`, config injected). Reads `config.local.host.displays.primary` for `ScreenWidth` / `ScreenHeight`. Sets up `/var/cache/sddm-wallpaper/current` as the shared background path that gets updated at runtime — see [[Concepts/SDDM wallpaper sync]] |
| `wayland-env.nix` | `NIXOS_OZONE_WL = "1"` (electron apps use Wayland) + `MOZ_ENABLE_WAYLAND = "1"` |

`hyprland.enable` is the SYSTEM-level enable. Per-user hyprland config (keybinds, workspaces, theming) lives in [[Home modules/Desktop/WM/Hyprland]].

`sddm.nix` builds a derivation `nyx-theme` that:
1. Copies the `sddm-astronaut` theme into a new theme dir
2. Patches `metadata.desktop` to rename it
3. Writes our `nyx.conf` (custom palette, fonts, layout) into `Themes/`

The shared wallpaper file is world-writable on purpose so `sddm-update-wallpaper` (in [[Home modules/Desktop/WM/Wallpaper]]) can update it without sudo when the user changes wallpapers.

## See also

- [[Concepts/Host config (data flow)]] — how `local.host.displays.primary` reaches `sddm.nix`
- [[Home modules/Desktop/WM/Hyprland]] — user-side hyprland config
- [[Home modules/Desktop/WM/Wallpaper]] — the wallpaper sync helper

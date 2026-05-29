# SDDM wallpaper sync

The SDDM login screen background matches the active desktop wallpaper — even though SDDM runs as the `sddm` user before any user logs in.

## The shared file

`modules/desktop/wm/sddm.nix`:

```nix
systemd.tmpfiles.rules = [
  "d /var/cache/sddm-wallpaper 0755 sddm sddm -"
  "C /var/cache/sddm-wallpaper/current 0666 sddm sddm - ${pkgs.sddm-astronaut}/share/sddm/themes/sddm-astronaut-theme/Backgrounds/hyprland_kath.png"
];
```

Creates `/var/cache/sddm-wallpaper/current` (mode `0666` — world-writable). On first boot it's seeded with the upstream `hyprland_kath.png`. Mode `0666` is deliberate: any user can `cp` over it without sudo.

The SDDM theme config (`nyx.conf` baked into `nyx-theme`) points its `Background=file://...` at this file:

```ini
BackgroundPlaceholder=Backgrounds/hyprland_kath.png
Background=file:///var/cache/sddm-wallpaper/current
```

`BackgroundPlaceholder` is the fallback in case the cache file is somehow gone.

## The updater

`home-modules/desktop/wm/wallpaper/sync.nix` packages `sddm-update-wallpaper`:

```sh
sddm-update-wallpaper [<path>]
```

If no arg: queries `swww` for the current wallpaper. Then `cp` it to `/var/cache/sddm-wallpaper/current`.

## Triggers

- **waypaper** — its config sets `post_command = sddm-update-wallpaper`. After any wallpaper change via waypaper, the sync runs.
- **wofi-theme-switcher** — explicit `sddm-update-wallpaper "$wallpaper"` after picking a random wallpaper from the theme pool ([[Concepts/Theme switching]]).

## Why not run SDDM as the user who set the wallpaper?

SDDM runs before login — there's no user session yet. The shared file is the simplest workaround that doesn't require a service writing to SDDM-owned state.

## See also

- [[Modules/Desktop/WM]] — sddm module
- [[Home modules/Desktop/WM/Wallpaper]] — the updater + waypaper config
- [[Concepts/Theme switching]]

# Wallpaper

`home-modules/desktop/wm/wallpaper/`. Two files plus the swww + waypaper packages.

```
wallpaper/
├── default.nix       installs swww + waypaper
├── waypaper.nix      one-time config bootstrap (activation script)
└── sync.nix          packages sddm-update-wallpaper helper
```

## Stack
- `swww` — actual wallpaper engine (`swww-daemon`)
- `waypaper` — GUI picker that drives swww
- `sddm-update-wallpaper` — custom script that copies the current wallpaper to `/var/cache/sddm-wallpaper/current` so the SDDM login screen matches the desktop background

## waypaper config bootstrap (`waypaper.nix`)

Waypaper's `~/.config/waypaper/config.ini` is runtime-mutable — it writes back when the user picks a wallpaper, and `wofi-theme-switcher` rewrites the `folder` line. So home-manager only creates it on first activation (`if [ ! -f "$CONFIG" ]`); subsequent activations do not overwrite.

Defaults written on bootstrap:
- `folder = ~/Media/Wallpapers/Gruvbox`
- `wallpaper = ~/Media/Wallpapers/Gruvbox/Gruvbox-Face.png`
- `backend = swww`
- `fill = fill`
- `post_command = sddm-update-wallpaper`

`post_command` runs after every waypaper apply, which keeps the SDDM background in sync.

## SDDM sync (`sync.nix`)

`sddm-update-wallpaper` packaged as `pkgs.writeShellScriptBin`:

```sh
sddm-update-wallpaper [<path>]
```

If no arg given, asks swww via `swww query`. Then `cp` to `/var/cache/sddm-wallpaper/current`. That destination is created world-writable by `modules/desktop/wm/sddm.nix` so this script doesn't need sudo.

Full SDDM background pipeline writeup: [[Concepts/SDDM wallpaper sync]].

## See also

- `SUPER+W` opens waypaper ([[Home modules/Desktop/WM/Hyprland]])
- [[Concepts/Theme switching]] — `wofi-theme-switcher` picks a random wallpaper from the theme's folder

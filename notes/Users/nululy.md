# nululy

Secondary user. Desktop + cli + dev, no nvf, no gaming.

## `modules.nix`
- `extraGroups = [ "wheel" "networkmanager" ]`
- shell defaults to bash (not fish)
- no lingering

## `default.nix` imports

```
home-modules/base.nix
home-modules/desktop
home-modules/cli
./dirs.nix
home-modules/dev
```

## `dirs.nix`

Same XDG layout as [[Users/neburion]]'s but only the public-facing dirs — no `Wallpapers/<Theme>` subdirs and no `Projects` tree. (See `users/nululy/dirs.nix` for the actual contents.)

Note: theme switching still works for nululy because all the directories that wofi-theme-switcher creates symlinks under are home-manager-owned; what it CAN'T do is pick a wallpaper at random (no Wallpapers/ subdir to read from). If nululy wants wallpaper rotation, the dirs need to exist.

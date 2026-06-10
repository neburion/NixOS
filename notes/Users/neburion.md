# neburion

Primary user. Full developer + desktop stack.

## `modules.nix`
- `extraGroups = [ "wheel" "networkmanager" ]` — sudo + NM
- `shell = pkgs.fish`
- Lingering enabled via `systemd.tmpfiles` (`/var/lib/systemd/linger/neburion`)

## `default.nix` imports

```
home-modules/base.nix
home-modules/desktop
home-modules/desktop/gaming
home-modules/cli
./dirs.nix
home-modules/dev
home-modules/dev/nvf.nix    ← neburion-only
```

## `dirs.nix` — XDG tree

```
~/Docs
~/Downloads
~/Media/Image (+ Screenshot)
~/Media/Video
~/Media/Music
~/Media/Wallpapers
  ├── Catppuccin
  ├── Dark
  ├── Everforest
  ├── Gruvbox
  └── Nord
~/Projects
  ├── Dev
  ├── Art
  └── Tower
```

The `Wallpapers/<Theme>` subdirs are required by [[Home modules/Desktop/WM/Wallpaper]]'s waypaper config and by `wofi-theme-switcher` (which picks random files from the matching directory on theme change — see [[Concepts/Theme switching]]).

## See also

- [[Users/Overview]]
- [[Home modules/Dev/Overview]] — what dev gives neburion
- [[Home modules/CLI/Neovim]] — nvf config (active for neburion only)

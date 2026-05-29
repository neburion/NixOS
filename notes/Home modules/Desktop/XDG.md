# XDG

`home-modules/desktop/xdg.nix`. XDG defaults for every desktop user.

## What it sets

- `xdg.mimeApps.enable = true` — required for the per-app mime contributions ([[Home modules/Desktop/Apps]]) to actually take effect
- `xdg.configFile."user-dirs.dirs".force = true` — overrides the read-only home-manager symlink so `xdg-user-dirs-update` can edit it
- `xdg.userDirs` — custom paths:

| Dir | Path |
|---|---|
| documents | `~/Docs` |
| download | `~/Downloads` |
| pictures | `~/Media/Image` |
| videos | `~/Media/Video` |
| music | `~/Media/Music` |
| desktop | `~/.local/share/desktop` (hide it) |
| templates | `~/.local/share/templates` (hide it) |
| publicShare | `~/.local/share/public` (hide it) |

`createDirectories = false` — directories are NOT created by xdg. They're created declaratively by each user's `dirs.nix` via `systemd.tmpfiles` ([[Users/Overview]]).

## See also

- [[Users/neburion]] — example `dirs.nix` with the full Projects + Wallpapers tree
- [[Home modules/Desktop/Apps]] — modules that contribute `xdg.mimeApps.defaultApplications` entries

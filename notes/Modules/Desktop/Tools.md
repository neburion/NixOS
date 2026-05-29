# Desktop — Tools

`modules/desktop/tools/` — small system-level CLI utilities the desktop relies on.

| File | Package | Why system-level |
|---|---|---|
| `brightness.nix` | `brightnessctl` | Used by hyprland keybinds for `XF86MonBrightness{Up,Down}` |
| `xdg-user-dirs.nix` | `xdg-user-dirs` | Provides `xdg-user-dirs-update`; xdg directory enforcement in user space |

Each is a one-package module. They're separate because each is a discrete capability (a host without a laptop screen might not need brightnessctl, for example).

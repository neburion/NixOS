# Mako

`home-modules/desktop/wm/mako/default.nix`. Wayland notification daemon.

## Config

Base config (font, sizes, anchor, timeouts):
- FiraMono Nerd Font 11
- 300×100 capsule, 10 margin, 15 padding, 12 radius, 1px border
- `default-timeout = 5000`, `max-visible = 5`, `max-history = 10`
- `layer = overlay`, `anchor = top-right`
- `on-button-left = dismiss`, middle/right → none

## Theme files

Each palette in `themes` generates `~/.config/mako/themes/<name>` containing:
- base config above
- + `background-color = ${c.bg}`, `text-color = ${c.fg}`, `border-color = ${c.surface}`

Unlike waybar/wofi which use CSS @import for the active palette, mako has no include directive — `wofi-theme-switcher` overwrites `~/.config/mako/config` from `themes/<chosen>` directly, then `makoctl reload`.

## See also

- [[Concepts/Theme switching]]
- Triggered indirectly via libnotify (most apps)

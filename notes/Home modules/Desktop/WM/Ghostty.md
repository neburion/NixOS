# Ghostty

`home-modules/desktop/wm/terminal/ghostty.nix`. Terminal emulator.

## Settings

- `font-family = "FiraMono Nerd Font"`, size 11
- `cursor-style = block`
- `shell-integration-features = "no-cursor"` — avoid cursor blink override
- `config-file = ~/.config/ghostty/themes/active.conf` — runtime-managed file

## Theme files

For each palette in `themes`, generates `~/.config/ghostty/themes/<name>` with:
- background, foreground, cursor color
- selection-background, selection-foreground

The `active.conf` file is a single-line `theme = <name>` file owned by `wofi-theme-switcher`. On theme change:

```sh
echo "theme = $chosen" > "$GHOSTTY_THEMES/active.conf"
pkill -SIGUSR2 ghostty 2>/dev/null || true
```

`SIGUSR2` to ghostty ≥1.2 triggers a live config reload — running terminals update without restart.

Created on first activation if missing (writes `theme = dark` as default).

## See also

- [[Concepts/Theme switching]]
- Launched by `SUPER+Return` ([[Home modules/Desktop/WM/Hyprland]])

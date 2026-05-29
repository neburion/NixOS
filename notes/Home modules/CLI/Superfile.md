# Superfile

`home-modules/cli/superfile.nix`. TUI file manager.

## Config

```nix
programs.superfile.settings = {
  editor     = "nvim";
  dir_editor = "nvim";
  ignore_missing_fields = true;
  theme = "active";   # not a real built-in, see below
};
```

`theme = "active"` is a placeholder name — the real theme is symlinked to `~/.config/superfile/theme/active.toml` and resolved at runtime.

## Theme-sync activation

The activation script `syncSuperfileTheme` runs after [[Home modules/Desktop/WM/Hyprland]]'s `initHyprTheme`. It reads `~/.config/hypr/theme.conf` (which is a symlink whose basename is the active palette), looks up the matching superfile theme via a baked-in case statement (from the palette's `superfileTheme` field), and symlinks `active.toml` to it.

Superfile extracts built-in themes to `~/.config/superfile/theme/` on first launch, so the activation silently no-ops until that directory exists.

Switching themes at runtime is handled by `wofi-theme-switcher` — see [[Concepts/Theme switching]].

## See also

- [[Home modules/Themes]] — palette schema (each palette declares its preferred `superfileTheme`)

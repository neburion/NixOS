# Themes

`home-modules/themes/` — palette definitions consumed by every theme-aware module.

```
themes/
├── default.nix       attrset: { catppuccin = import ./…; dark = …; … }
├── catppuccin.nix
├── dark.nix
├── everforest.nix
├── gruvbox.nix
└── nord.nix
```

## Palette schema

Each palette is a plain attrset:

```nix
{
  bg             = "#111111";
  surface        = "#222222";
  selection      = "#333333";
  fg             = "#ffffff";
  wallpaperDir   = "Dark";             # subfolder under ~/Media/Wallpapers/
  gtkTheme       = "Adwaita-dark";     # GTK theme name to gsettings-set
  fishPrimary    = "#aaaaaa";          # fish prompt main color
  fishSecondary  = "#666666";          # fish prompt secondary
  superfileTheme = "onedark";          # name of a superfile built-in theme
}
```

`default.nix` exports them as an attrset keyed by name. Used by:
- [[Home modules/Desktop/WM/Hyprland]] (shadow color)
- [[Home modules/Desktop/WM/Waybar]] (`@define-color`)
- [[Home modules/Desktop/WM/Wofi]] (CSS)
- [[Home modules/Desktop/WM/Mako]] (config file)
- [[Home modules/Desktop/WM/Ghostty]] (terminal palette)
- [[Home modules/Desktop/WM/GTK]] (GTK3 / GTK4 CSS via `css.nix`)
- [[Home modules/CLI/Superfile]] (theme name lookup)
- [[Home modules/CLI/Fish]] (universal vars for prompt color)
- [[Concepts/Theme switching]] (the switcher walks every entry)

## How modules access `themes`

`flake.nix` injects it as `_module.args.themes` in `home-manager.sharedModules`. Consumers just declare `{ themes, ... }: ...` in their module signature.

This replaces a previous pattern of `import ../../../themes` from each consumer (path-traversal coupling).

## Adding a new theme

[[How to#Add a new theme]] for the full walkthrough.

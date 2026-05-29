# Tools

`home-modules/desktop/tools/` — CLI tool pipelines composed in user space.

## `screenshot.nix`

```nix
home.packages = [ grim slurp wl-clipboard ];
```

These three together compose the screenshot pipeline:
- `slurp` — area selector (`$(slurp)`)
- `grim` — capture
- `wl-clipboard` — `wl-copy` puts the PNG on the wayland clipboard

Hyprland binds:
- `Print` — area screenshot, save to `~/Media/Image/Screenshot/<timestamp>_screenshot.png` and copy to clipboard
- `Shift+Print` — full-screen screenshot, same destination

Bound in [[Home modules/Desktop/WM/Hyprland]]'s `keybinds.nix`.

Bundled in one file because they're useless apart — like `compression.nix` in [[Home modules/CLI/AppImage Compression Flatpak]].

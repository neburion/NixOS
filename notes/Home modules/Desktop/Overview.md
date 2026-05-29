# Desktop overview (home-manager)

`home-modules/desktop/` — per-user desktop stack.

```
desktop/
├── default.nix      imports apps/ services/ tools/ art/ wm/ xdg.nix
├── xdg.nix          xdg.mimeApps.enable + user-dirs override
├── apps/            user-facing apps grouped by capability
├── services/        background services (currently: tray applets)
├── tools/           CLI tool bundles (currently: screenshot)
├── art/             (existing) aseprite + blender
└── wm/              window manager configs (hyprland, waybar, wofi, …)
```

## Subdir notes

- [[Home modules/Desktop/Apps]] — browser · comms · files · media · productivity
- [[Home modules/Desktop/Services]] — tray applets
- [[Home modules/Desktop/Tools]] — screenshot
- [[Home modules/Desktop/Art]]
- [[Home modules/Desktop/XDG]]
- WM:
    - [[Home modules/Desktop/WM/Hyprland]] (multi-file subdir)
    - [[Home modules/Desktop/WM/Waybar]]
    - [[Home modules/Desktop/WM/Wofi]]
    - [[Home modules/Desktop/WM/Mako]]
    - [[Home modules/Desktop/WM/Ghostty]]
    - [[Home modules/Desktop/WM/Wallpaper]]
    - [[Home modules/Desktop/WM/GTK]]

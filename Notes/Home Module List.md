Home-manager modules, selected per user in `users/<name>.nix`.

## `desktop/`
The desktop module imports everything needed for the graphical environment.

```
desktop/
├── default.nix       # Imports wm/, gaming/, art/ + desktop packages + XDG dirs
├── wm/               # Window manager stack — see [[Hyprland]]
│   ├── default.nix   # Imports hyprland/, ghostty, waybar/, wofi/, mako/, wallpaper/, gtk.nix
│   ├── hyprland/     # Hyprland WM config — see [[Hyprland]]
│   ├── waybar/       # Status bar
│   ├── wofi/         # App launcher + scripts (theme switcher, power menu)
│   ├── mako/         # Notification daemon
│   ├── wallpaper/    # swww + waypaper — see [[Wallpaper]]
│   └── gtk.nix       # GTK theme, icon theme, font — see [[Theme Switching]]
├── gaming/           # Heroic launcher, PrismLauncher (Minecraft)
└── art/              # Art tools
```

**Packages in `desktop/default.nix`:**
blueman, networkmanagerapplet, loupe, celluloid, thunar, pavucontrol, keepassxc, solaar, razergenie, grim, slurp, wl-clipboard, ente-desktop, spotify, signal-desktop, vesktop, obsidian, obs-studio

## `cli/`

| File | What it does |
|------|-------------|
| `fish.nix` | Fish shell, aliases, custom prompt |
| `git.nix` | Git config |
| `superfile.nix` | Superfile TUI file manager |
| `neovim/` | Neovim via nvf — see [[Neovim]] |
| `backup.nix` | Backup script (currently broken) |

**Packages in `cli/default.nix`:**
p7zip, unrar, unzip, btop, fastfetch, tree, appimage-run + Flatpak remote setup

## `dev/`

| File | What it does |
|------|-------------|
| `scripts/` | Project bootstrap scripts: `newc`, `newcpp`, `newpy` |
| `ai/` | AI CLI tools: `claude-code`, `opencode` (with patched LD_LIBRARY_PATH) |

**Packages in `dev/default.nix`:**
gcc, python3, gnumake, cmake, gdb, godot, direnv + nix-direnv

## `themes/`
Color definitions used at build time to generate CSS/config files. Not imported directly by users — consumed by `wm/wofi/`, `wm/waybar/`, `wm/mako/`.
See [[Theme Switching]].

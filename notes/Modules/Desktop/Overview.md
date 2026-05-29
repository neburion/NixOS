# Desktop modules — overview

`modules/desktop/` — system-level desktop stack. Mix of subdirs (multi-item categories) and flat files (single concerns).

```
modules/desktop/
├── default.nix              imports all of the below
├── fonts.nix
├── gaming.nix
├── remote-access.nix
├── wm/                      hyprland · sddm · wayland-env
├── integrations/            dconf · flatpak · kdeconnect
├── tools/                   brightness · xdg-user-dirs
└── quirks/                  electron (insecure allowlist for Obsidian)
```

## Subdir notes

| Note | What's inside |
|---|---|
| [[Modules/Desktop/WM]] | hyprland enable, SDDM theme, wayland env vars |
| [[Modules/Desktop/Integrations]] | dconf, flatpak service, kdeconnect |
| [[Modules/Desktop/Tools]] | brightnessctl, xdg-user-dirs |
| [[Modules/Desktop/Quirks]] | electron allowlist |
| [[Modules/Desktop/Gaming]] | Steam + Proton GE + JDK25 + per-user launcher gating |
| [[Modules/Desktop/Fonts]] | Fira Mono Nerd Font |
| [[Modules/Desktop/Remote access]] | rustdesk |

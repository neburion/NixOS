# NixOS Config Notes

Personal documentation for the `~/NixOS` flake. Built around three principles:

1. **Modularity** — one concern per module; capabilities grouped into subdirs
2. **Declarativity** — typed options over imperative scripts
3. **Portability** — host-specific data lives in `hosts/`, modules are reusable

See [[Principles]] for the full reasoning, [[Architecture]] for the directory layout.

## Where to start

- New to the config → [[Architecture]] → [[Hosts/Overview]]
- Rebuilding → [[Build & rebuild]]
- Looking up a feature → use the maps below
- Doing something specific → [[How to]]

## Map — Modules (system level)

- [[Modules/Overview]]
- [[Modules/Core]] — nix, locale, security, shell essentials
- [[Modules/Audio]] · [[Modules/Boot]] · [[Modules/Network]]
- [[Modules/Hardware]] — bluetooth, graphics, nvidia, touchpad, power-profiles (à la carte)
- [[Modules/Host options]] — `local.host.*` typed options for per-host data
- Desktop:
    - [[Modules/Desktop/Overview]]
    - [[Modules/Desktop/WM]] (hyprland enable, sddm, wayland env)
    - [[Modules/Desktop/Integrations]] (dconf, flatpak, kdeconnect)
    - [[Modules/Desktop/Tools]] (brightness, xdg-user-dirs)
    - [[Modules/Desktop/Quirks]] (electron allowlist)
    - [[Modules/Desktop/Gaming]] · [[Modules/Desktop/Fonts]] · [[Modules/Desktop/Remote access]]

## Map — Home modules (per-user)

- [[Home modules/Overview]]
- CLI:
    - [[Home modules/CLI/Overview]]
    - [[Home modules/CLI/Fish]] · [[Home modules/CLI/Git]] · [[Home modules/CLI/Superfile]] · [[Home modules/CLI/Neovim]]
    - [[Home modules/CLI/AppImage Compression Flatpak]]
- Desktop:
    - [[Home modules/Desktop/Overview]]
    - [[Home modules/Desktop/Apps]] (browser, comms, files, media, productivity)
    - [[Home modules/Desktop/Services]] (tray)
    - [[Home modules/Desktop/Tools]] (screenshot)
    - [[Home modules/Desktop/Art]] · [[Home modules/Desktop/XDG]]
    - WM:
        - [[Home modules/Desktop/WM/Hyprland]]
        - [[Home modules/Desktop/WM/Waybar]]
        - [[Home modules/Desktop/WM/Wofi]]
        - [[Home modules/Desktop/WM/Mako]]
        - [[Home modules/Desktop/WM/Ghostty]]
        - [[Home modules/Desktop/WM/Wallpaper]]
        - [[Home modules/Desktop/WM/GTK]]
- [[Home modules/Dev/Overview]] · [[Home modules/Themes]]

## Map — Hosts & Users

- [[Hosts/Overview]] — [[Hosts/pod042]], [[Hosts/installer]]
- [[Users/Overview]] — [[Users/neburion]], [[Users/nululy]], [[Users/qellyree]]

## Map — Concepts (cross-module)

- [[Concepts/Theme switching]] — how palettes propagate at runtime
- [[Concepts/Host config (data flow)]] — how `local.host` reaches home-manager
- [[Concepts/Hyprland session restore]]
- [[Concepts/SDDM wallpaper sync]]
- [[Concepts/Gaming launcher gating]]

## How to

[[How to]] — one note with sections for the common tasks.

# Desktop — Integrations

`modules/desktop/integrations/` — system services that desktop apps depend on.

| File | What it does |
|---|---|
| `dconf.nix` | `programs.dconf.enable = true` — required for Nautilus dark theme in non-GNOME sessions |
| `flatpak.nix` | `services.flatpak.enable = true` |
| `kdeconnect.nix` | `programs.kdeconnect.enable = true` |

`dconf` is here, not bundled with home-manager GTK config, because it's a system-level program prerequisite. The comment in the file documents that it's needed for Nautilus.

`flatpak` enables the system service. The home-manager side ([[Home modules/CLI/AppImage Compression Flatpak]]) adds the flathub remote on first activation.

## See also

- [[Home modules/Desktop/WM/GTK]] — Nautilus theming
- [[Home modules/CLI/AppImage Compression Flatpak]] — flathub remote setup

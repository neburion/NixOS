System-level NixOS modules, imported by host `configuration.nix` files.

## `core/`

| File | What it does |
|------|-------------|
| `networking.nix` | Sets hostname (`pod042`), enables NetworkManager, OpenSSH, LocalSend |
| `hardware.nix` | Nvidia drivers (PRIME offload, Intel+Nvidia), Bluetooth, touchpad, power profiles |
| `audio.nix` | Audio setup (PipeWire assumed) |
| `boot.nix` | Bootloader configuration |
| `locale.nix` | Timezone, locale settings |
| `syncthing.nix` | Syncthing service — syncs `~/Docs/Passwords` with phone |

## `desktop/`

| File | What it does |
|------|-------------|
| `default.nix` | Hyprland + XWayland, SDDM (astronaut theme), Flatpak, KDE Connect, FiraMono Nerd Font, Wayland env vars |
| `gaming.nix` | Steam (Proton-GE, remote play), JDK 25 (Minecraft) |
| `remote-access.nix` | Remote access tooling |
| `emulation/` | Waydroid (currently non-functional) |

## Hardware Notes (pod042)
- **GPU:** Nvidia (PRIME offload) + Intel iGPU
  - Intel Bus: `PCI:0:2:0`
  - Nvidia Bus: `PCI:1:0:0`
  - Uses open kernel module
- **Monitors:** `eDP-1` (built-in, 1080p@120Hz) + `HDMI-A-1` (external, 1080p@144Hz)

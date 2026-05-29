# Services

`home-modules/desktop/services/` — background services (currently just tray applets).

## `tray.nix`

```nix
home.packages = [
  blueman              # Bluetooth applet
  networkmanagerapplet # Network applet
  pavucontrol          # Audio control
  razergenie           # Razer device manager
  solaar               # Logitech device manager
];
```

Five tray applets bundled in one file. They share the capability "system tray UIs for managing background services/hardware." If you ever want different tray combinations per user (e.g. nululy doesn't use Razer gear), split this file.

[[Home modules/Desktop/WM/Hyprland]] auto-execs `nm-applet` and `blueman-applet` on session start (`auto-exec.nix`). `pavucontrol` is launched on demand by waybar's pulseaudio click, and by `SUPER+A`.

## See also

- [[Modules/Hardware]] — bluetooth, power-profiles modules these UIs talk to
- [[Modules/Audio]] — pipewire that pavucontrol controls

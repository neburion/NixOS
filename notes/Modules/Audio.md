# Audio

`modules/audio/pipewire.nix`. Standalone subdir.

- `security.rtkit.enable = true` — RT scheduling for audio
- `services.pipewire.enable` + `alsa.enable` + `pulse.enable` + `wireplumber.enable`

PulseAudio compat layer is on — apps that expect Pulse work without modification.

For user-facing volume control: [[Home modules/Desktop/Services]] installs `pavucontrol`, and [[Home modules/Desktop/WM/Waybar]] uses `wpctl` for keybinds.

## See also

- [[Modules/Hardware]] — bluetooth
- Keybinds in [[Home modules/Desktop/WM/Hyprland]] use `wpctl` to bind volume keys

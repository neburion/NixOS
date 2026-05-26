## System
- [ ] Clean up the ISO file generation logic
- [ ] Remove all modules in the host directory
- [ ] Restructure modules and home-modules so they can be more interchangeable
- [ ] Fix backup.nix (currently broken)
- [ ] Fix emulation/waydroid (currently non-functional, consider moving out of desktop/)
- [ ] Split `modules/desktop/default.nix` into smaller modules

## Theme Switching (bugs)
- [ ] Remove duplicate mako systemd service from `mako/default.nix` (conflicts with `services.mako`)
- [ ] Remove stray `xdg.configFile."mako/config".force = true` from `mako/config.nix`
- [ ] Fix waybar restart: change `pkill waybar && waybar &` to `pkill waybar; waybar &`
- [ ] Fix GTK theme persistence (currently resets on every `home-manager switch`)

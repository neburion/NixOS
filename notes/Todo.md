## System
- [ ] Clean up the ISO file generation logic
- [ ] Remove all modules in the host directory
- [ ] Restructure modules and home-modules so they can be more interchangeable
- [ ] Fix backup.nix (currently broken)
- [ ] Fix emulation/waydroid (currently non-functional, consider moving out of desktop/)
- [ ] Split `modules/desktop/default.nix` into smaller modules

## Theme Switching
All previously-tracked bugs (mako dual service, stray `xdg.configFile` force, waybar restart with `&&`, GTK theme reset) are resolved. See [[Theme Switching]] for the current persistence model.

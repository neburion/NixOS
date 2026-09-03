{ ... }:

# Configuration GUIs for the mouse and keyboard.
#
# logitech/ carries a system.nix as well (hardware.logitech.wireless), imported
# by the host — solaar's GUI is useless without the daemon side.

{
  imports = [
    ../peripherals/logitech
    ../peripherals/razer-genie.nix
  ];
}

{ ... }:

# The mouse and the headset, and how to read what is left in each.
#
# Both carry a system.nix as well — hardware.logitech.wireless for the one, a
# udev handover for the other — imported by the host. Neither reader works
# without its half.

{
  imports = [
    ../peripherals/logitech
    ../peripherals/razer-nari
  ];
}

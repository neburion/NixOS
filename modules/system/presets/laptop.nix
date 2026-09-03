{ ... }:

# A machine with a lid, a battery and speakers.

{
  imports = [
    ../hardware/audio.nix
    ../hardware/bluetooth.nix
    ../hardware/brightness.nix
    ../hardware/lid.nix
    ../hardware/power-profiles.nix
    ../hardware/touchpad.nix
  ];
}

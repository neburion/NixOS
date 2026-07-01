{ ... }:

{
  imports = [
    ./hardware-configuration.nix

    ./hardware-layout

    ../../modules/system/nixos.nix
    ../../modules/system/boot
    ../../modules/system/hardware/nvidia.nix
    ../../modules/system/hardware/touchpad.nix
    ../../modules/system/hardware/brightness.nix
    ../../modules/system/locale.nix
    ../../modules/system/networking
    ../../modules/system/bluetooth.nix
    ../../modules/system/audio.nix
    ../../modules/system/flatpak.nix
    ../../modules/system/power-profiles.nix
    ../../modules/system/xdg-user-dirs.nix

    ../../users/neburion
  ];

  networking.hostName = "pod042";
}

{ ... }:

{
  imports = [
    ./hardware-layout

    ../../modules/system/nixos.nix
    ../../modules/system/locale.nix
    ../../modules/system/boot/systemd-boot.nix
    ../../modules/system/networking/networkmanager.nix
    ../../modules/system/networking/ssh.nix
    ../../modules/system/always-on.nix
    ../../modules/system/power-profiles.nix
    ../../modules/system/printing

    ../../users/printer

    ./hardware-configuration.nix
  ];
}

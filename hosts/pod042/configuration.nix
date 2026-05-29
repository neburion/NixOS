{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./users.nix
    ../../modules/core/networking.nix
    ../../modules/core/syncthing.nix
    ../../modules/core/hardware.nix
    ../../modules/core/audio.nix
    ../../modules/core/locale.nix
    ../../modules/core/boot.nix
    ../../modules/core/nix.nix
    ../../modules/core/shell.nix
    ../../modules/core/security.nix
    ../../modules/desktop
  ];
}

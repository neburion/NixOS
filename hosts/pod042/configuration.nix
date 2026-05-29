{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ./host.nix
    ./users.nix
    ../../modules/audio
    ../../modules/boot
    ../../modules/core
    ../../modules/desktop
    ../../modules/network
  ];
}

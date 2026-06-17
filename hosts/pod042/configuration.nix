{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ./hostname.nix
    ./displays.nix
    ./users.nix
    ../../modules/audio
    ../../modules/boot
    ../../modules/core
    ../../modules/desktop
    ../../modules/network
    ../../modules/tools
  ];
}

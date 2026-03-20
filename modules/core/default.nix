{ ... }:
{
  imports = [
      ./hardware.nix
      ./networking.nix
      ./audio.nix
      ./users.nix
      ./locale.nix
      ./env.nix
      ./boot.nix
  ];
}

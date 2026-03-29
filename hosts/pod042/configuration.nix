{ ... }:

{
  imports =
    [ 
      ./hardware-configuration.nix
      ./users.nix
      ./networking.nix
      ../../modules/core/hardware.nix
      ../../modules/core/audio.nix
      ../../modules/core/locale.nix
      ../../modules/core/boot.nix
      ../../modules/core/env.nix # temporary
      ../../modules/desktop
      ../../modules/scripts/backup.nix
    ];

  # NixOS
  nixpkgs.config.allowUnfree = true; # Package Manager
  nix.settings.experimental-features = [ "flakes" "nix-command" ]; # Flake
  system.stateVersion = "25.11"; # Initial nixos version on install no need to change
}

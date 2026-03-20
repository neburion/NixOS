{ ... }:
{
  imports =
    [ 
      ./hardware-configuration.nix
      ./modules/core
      ./modules/desktop
      ./modules/scripts
    ];

  # NixOS
  nixpkgs.config.allowUnfree = true; # Package Manager
  home-manager.users.neburion = import ./home.nix; # Home Manager
  nix.settings.experimental-features = [ "flakes" "nix-command" ]; # Flake
  system.stateVersion = "25.11"; # Initial nixos version on install no need to change
}

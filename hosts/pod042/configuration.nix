{ ... }:
{
  imports =
    [
      ./hardware-configuration.nix
      ./users.nix
      ../../modules/core/networking.nix
      ../../modules/core/syncthing.nix
      ../../modules/core/hardware.nix
      ../../modules/core/audio.nix
      ../../modules/core/locale.nix
      ../../modules/core/boot.nix
      ../../modules/core/backup.nix
      ../../modules/desktop
      ../../modules/desktop/remote-access.nix
    ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "flakes" "nix-command" ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates     = "weekly";
    options   = "--delete-older-than 14d";
  };

  security.sudo.wheelNeedsPassword = false;
  system.stateVersion = "25.11"; # Initial nixos version on install no need to change

  programs.fish.enable = true;
  environment.sessionVariables = {
    EDITOR = "nvim";
    SUDO_EDITOR = "nvim";
  };
}

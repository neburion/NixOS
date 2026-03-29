{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./users.nix
    ./networking.nix
    ../../modules/lid-keep-on.nix
    ../../modules/locale.nix
    ../../modules/boot.nix

  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "25.11";
}

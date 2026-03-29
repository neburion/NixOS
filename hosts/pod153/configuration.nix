{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./users.nix
    ./networking.nix
    ../../modules/core/lid-keep-on.nix
    ../../modules/core/locale.nix
    ../../modules/core/boot.nix
    ../../modules/core/shell.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "25.11";
}

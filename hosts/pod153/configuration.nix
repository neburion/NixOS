{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./users.nix
    ./networking.nix
    ../../lid-keep-on.nix
    ../../locale.nix
    ../../boot.nix

  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "25.11";
}

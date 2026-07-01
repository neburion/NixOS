{ pkgs, lib, inputs, ... }:

{
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  boot.loader.grub.enable = lib.mkForce false; # remove if it doesn't need to stay
  boot.loader.efi.canTouchEfiVariables = true;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    configurationLimit = 1;  # only the latest NixOS generation shows in the boot menu
  };

  # sbctl: generates Secure Boot keys, enrolls them, verifies signatures.
  # Needed for Phase 2 (key enrollment); installing now so it's ready.
  environment.systemPackages = with pkgs; [ sbctl ];
}

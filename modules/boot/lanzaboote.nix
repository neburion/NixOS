{ pkgs, lib, inputs, ... }:

{
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  # Switching away from GRUB. lanzaboote drives systemd-boot under the hood
  # (and explicitly disables boot.loader.systemd-boot, so we don't set it).
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  # sbctl: generates Secure Boot keys, enrolls them, verifies signatures.
  # Needed for Phase 2 (key enrollment); installing now so it's ready.
  environment.systemPackages = with pkgs; [ sbctl ];
}

{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./hardware-layout

    ../../modules/system/nixos.nix
    ../../modules/system/locale.nix
    ../../modules/system/boot/systemd-boot.nix
    ../../modules/system/networking/networkmanager.nix
    ../../modules/system/networking/ssh.nix
    ../../modules/system/networking/ssh-password-auth.nix
    ../../modules/system/server.nix
    ../../modules/system/auto-upgrade.nix
    ../../modules/system/printing

    ../../users/printer
  ];

  networking.hostName = "print-server";

  system.autoUpgrade = {
    enable = true;
    flake  = "github:neburion/NixOS#print-server";
  };
}

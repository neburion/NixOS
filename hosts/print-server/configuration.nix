{ pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./hardware-layout

    ../../modules/system/nixos.nix
    ../../modules/system/locale.nix
    ../../modules/system/networking/networkmanager.nix
    ../../modules/system/networking/ssh.nix
    ../../modules/system/printing

    ../../users/printer
  ];

  networking.hostName = "print-server";

  boot.loader = {
    systemd-boot.enable      = true;
    efi.canTouchEfiVariables = true;
  };

  # networking/ssh.nix disables password auth; override until SSH keys are set up.
  services.openssh.settings.PasswordAuthentication = lib.mkForce true;

  users.mutableUsers = false;
  security.sudo.wheelNeedsPassword = true;

  # Always-on server: don't sleep or react to a closed lid.
  services.logind.settings.Login = {
    HandleLidSwitch              = "ignore";
    HandleLidSwitchDocked        = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };
  systemd.targets.sleep.enable        = false;
  systemd.targets.suspend.enable      = false;
  systemd.targets.hibernate.enable    = false;
  systemd.targets.hybrid-sleep.enable = false;

  # Weekly pull from the flake. allowReboot=false — a kernel bump won't
  # yank the printer out from under whoever's using it; reboot manually.
  system.autoUpgrade = {
    enable      = true;
    flake       = "github:neburion/NixOS#print-server";
    dates       = "weekly";
    allowReboot = false;
  };

  environment.systemPackages = with pkgs; [ htop ];
}

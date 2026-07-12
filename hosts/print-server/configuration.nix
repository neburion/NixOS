{ pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/system/nixos.nix
    ../../modules/system/locale.nix
    ../../modules/system/printing
  ];

  networking.hostName = "print-server";
  networking.networkmanager.enable = true;
  networking.networkmanager.ensureProfiles.profiles.home = {
    connection = { id = "BELL096"; type = "wifi"; };
    wifi = { mode = "infrastructure"; ssid = "BELL096"; };
    wifi-security = { key-mgmt = "wpa-psk"; psk = "9FCC749DC624"; };
    ipv4.method = "auto";
    ipv6.method = "auto";
  };

  # UEFI + systemd-boot. Older BIOS-only laptops will need a GRUB switch.
  boot.loader = {
    systemd-boot.enable      = true;
    efi.canTouchEfiVariables = true;
  };

  # SSH with password auth on for first login. Disable once keys are added.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin        = "no";
      PasswordAuthentication = true;
    };
  };

  users.mutableUsers = true;
  users.users.neburion = {
    isNormalUser    = true;
    extraGroups     = [ "wheel" "networkmanager" ];
    initialPassword = "printer";
  };
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

  environment.systemPackages = with pkgs; [ vim htop ];
}

{ pkgs, ... }:

{
  imports = [
    ./hardware-layout

    ../../modules/system/nixos.nix
    ../../modules/system/boot/lanzaboote.nix
    ../../modules/system/hardware/nvidia.nix
    ../../modules/system/hardware/touchpad.nix
    ../../modules/system/hardware/brightness.nix
    ../../modules/system/hardware/logitech.nix
    ../../modules/system/locale.nix
    ../../modules/system/networking/networkmanager.nix
    ../../modules/system/networking/ssh.nix
    ../../modules/system/networking/localsend.nix
    ../../modules/system/networking/syncthing.nix
    ../../modules/system/bluetooth.nix
    ../../modules/system/audio.nix
    ../../modules/system/flatpak.nix
    ../../modules/system/power-profiles.nix
    ../../modules/system/xdg-user-dirs.nix
    ../../modules/system/desktop

    ../../users/neburion
  ] ++ (if builtins.pathExists ./hardware-configuration.nix
        then [ ./hardware-configuration.nix ]
        else [ ]);

  #temp
  programs.fish.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };
  environment.pathsToLink = [ 
    "/share/applications" 
    "/share/xdg-desktop-portal" 
  ];

  networking.hostName = "pod042";
}

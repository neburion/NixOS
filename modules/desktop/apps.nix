{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    brightnessctl
    p7zip
    xdg-user-dirs
  ];

  programs.kdeconnect.enable = true;
  programs.dconf.enable      = true;  # required for Nautilus dark theme in non-GNOME sessions
  services.flatpak.enable    = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";     # electron apps use Wayland
    MOZ_ENABLE_WAYLAND = "1";
  };

  nixpkgs.config.permittedInsecurePackages = [
    "electron-38.8.4"  # obsidian on 25.11 uses electron_38
  ];
}

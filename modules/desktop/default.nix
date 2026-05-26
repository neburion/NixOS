{ pkgs, ... }:

{
  imports = [
    ./gaming.nix
  ];

  environment.systemPackages = with pkgs; [
    brightnessctl  # Brightness Manager
    xdg-user-dirs
    sddm-astronaut
  ];
  programs.kdeconnect.enable = true;
  programs.dconf.enable = true;

  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.fira-mono
  ];

  # Window Manager
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "sddm-astronaut-theme";
    extraPackages = [ pkgs.sddm-astronaut ];
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Make electron apps use Wayland
    MOZ_ENABLE_WAYLAND="1";
  };

  nixpkgs.config.permittedInsecurePackages = [
    "electron-38.8.4"
  ];

  services.flatpak.enable = true;
}

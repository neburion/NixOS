{ pkgs, ... }:

{
  imports = [
    ./gaming.nix
    ./emulation
  ];

  environment.systemPackages = with pkgs; [
    sddm-astronaut # SDDM Theme Manager
    brightnessctl # Brightness Manager
    xdg-user-dirs
    vesktop
  ];
  programs.kdeconnect.enable = true;

  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.fira-mono
  ];

  # Window Manager
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };
  #programs.sway.enable = true;

  # Login
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "sddm-astronaut-theme";
    extraPackages = [ pkgs.sddm-astronaut ];
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Make electron apps use Wayland
    MOZ_ENABLE_WAYLAND=1;
  };
}

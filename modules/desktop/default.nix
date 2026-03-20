{ pkgs, ... }:
{
  import = [
    ./gaming.nix
    ./emulation
  ];

  environment.systemPackages = with pkgs; [
    sddm-astronaut # SDDM Theme Manager
    brightnessctl # Brightness Manager
    xdg-user-dirs
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

  # Login
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "sddm-astronaut-theme";
    extraPackages = [ pkgs.sddm-astronaut ];
  };
}

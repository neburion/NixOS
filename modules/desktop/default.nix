{ pkgs, ... }:

let
  sddm-theme = pkgs.sddm-astronaut.override {
    embeddedTheme = "hyprland_kath";
    themeConfig = {
      Font     = "FiraMono Nerd Font";
      FontSize = "11";
    };
  };
in
{
  imports = [
    ./gaming.nix
  ];

  environment.systemPackages = with pkgs; [
    brightnessctl  # Brightness Manager
    xdg-user-dirs
    sddm-theme
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
    extraPackages = with pkgs; [
      sddm-theme
      qt6Packages.qtmultimedia
      qt6Packages.qtsvg
      qt6Packages.qtvirtualkeyboard
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-libav
    ];
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

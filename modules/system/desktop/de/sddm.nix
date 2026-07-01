{ pkgs, ... }:
{
  services.displayManager.autoLogin = {
    enable = true;
    user   = "neburion";
  };

  services.displayManager.defaultSession = "hyprland";

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "sddm-astronaut-theme";
    extraPackages = with pkgs; [
      (sddm-astronaut.override { embeddedTheme = "purple_leaves"; })
      kdePackages.qtmultimedia
      kdePackages.qtsvg
      kdePackages.qtvirtualkeyboard
    ];
  };

  environment.systemPackages = with pkgs; [
    (sddm-astronaut.override { embeddedTheme = "purple_leaves"; })
  ];
}

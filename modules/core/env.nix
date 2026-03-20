{ ... }:
{
  # Environment Variables
  environment.sessionVariables = {
    EDITOR = "nvim";
    SUDO_EDITOR = "nvim";
    NIXOS_OZONE_WL = "1"; # Make electron apps use Wayland
  };
}

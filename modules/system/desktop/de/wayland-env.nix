{ ... }:

{
  environment.sessionVariables = {
    NIXOS_OZONE_WL     = "1";  # electron apps use Wayland
    MOZ_ENABLE_WAYLAND = "1";
  };
}

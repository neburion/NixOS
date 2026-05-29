{ ... }:

{
  imports = [
    ../../modules/host
  ];

  networking.hostName = "pod042";

  local.host.displays = {
    primary = {
      width  = 1920;
      height = 1080;
    };

    monitors = {
      builtin = {
        name     = "eDP-1";
        mode     = "1920x1080@120";
        position = "0x0";
      };
      external = {
        name     = "HDMI-A-1";
        mode     = "1920x1080@144";
        position = "1920x0";
      };
    };
  };
}

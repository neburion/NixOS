{ lib, ... }:

{
  options.displays = {
    primary = lib.mkOption { type = lib.types.attrs; };
    monitors = lib.mkOption { type = lib.types.attrs; };
  };

  config.displays = {
    primary = {
      width  = 1920;
      height = 1080;
    };

    monitors = {
      builtin = {
        name     = "eDP-1";
        mode     = "1920x1080@120";
        position = "0x0";
        scale    = "1";
      };
      external = {
        name     = "HDMI-A-1";
        mode     = "1920x1080@60";
        position = "1920x0";
        scale    = "1";
      };
    };
  };
}

{ lib, ... }:

{
  options.backlight = {
    sysfsBrightnessPath    = lib.mkOption { type = lib.types.str; };
    sysfsMaxBrightnessPath = lib.mkOption { type = lib.types.str; };
  };

  config.backlight = {
    sysfsBrightnessPath    = "/sys/class/backlight/nvidia_wmi_ec_backlight/brightness";
    sysfsMaxBrightnessPath = "/sys/class/backlight/nvidia_wmi_ec_backlight/max_brightness";
  };
}

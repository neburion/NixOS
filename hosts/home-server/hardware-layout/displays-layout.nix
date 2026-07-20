{ lib, ... }:

{
  options.displays = {
    primary  = lib.mkOption { type = lib.types.attrs; default = {}; };
    monitors = lib.mkOption { type = lib.types.attrs; default = {}; };
  };
}

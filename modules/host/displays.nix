{ lib, ... }:

{
  options.local.host.displays = {
    primary = lib.mkOption {
      description = "Primary display dimensions, used by the login manager.";
      type = lib.types.submodule {
        options = {
          width  = lib.mkOption { type = lib.types.int; };
          height = lib.mkOption { type = lib.types.int; };
        };
      };
    };

    monitors = lib.mkOption {
      description = "Physical displays attached to this host, keyed by logical role (e.g. builtin, external).";
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          name     = lib.mkOption { type = lib.types.str; description = "Output name (e.g. eDP-1)."; };
          mode     = lib.mkOption { type = lib.types.str; description = "Resolution@refresh-rate (e.g. 1920x1080@120)."; };
          position = lib.mkOption { type = lib.types.str; description = "Position relative to origin (e.g. 0x0)."; };
          scale    = lib.mkOption { type = lib.types.str; default = "1"; };
        };
      });
    };
  };
}

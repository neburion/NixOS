{ lib, themes, ... }:

let
  mkWaybarTheme = c: ''
    @define-color background ${c.bg};
    @define-color capsule ${c.surface};
    @define-color text ${c.fg};
    @define-color selection ${c.selection};
  '';
in
{
  xdg.configFile = lib.mapAttrs' (name: colors:
    lib.nameValuePair "waybar/themes/${name}.css" { text = mkWaybarTheme colors; }
  ) themes;
}

{ pkgs, lib, config, ... }:

let
  themes = {
    catppuccin = import ../../themes/catppuccin.nix;
    dark       = import ../../themes/dark.nix;
    everforest = import ../../themes/everforest.nix;
    gruvbox    = import ../../themes/gruvbox.nix;
    nord       = import ../../themes/nord.nix;
  };

  mkWaybarTheme = c: ''
    @define-color background ${c.bg};
    @define-color capsule ${c.surface};
    @define-color text ${c.fg};
    @define-color selection ${c.selection};
  '';
in
{
  imports = [
    ./config.nix
    ./scripts/current-power.nix
    ./scripts/power-toggle.nix
  ];

  xdg.configFile = lib.mapAttrs' (name: colors:
    lib.nameValuePair "waybar/themes/${name}.css" { text = mkWaybarTheme colors; }
  ) themes;

  programs.waybar.style =
    ''@import "${config.home.homeDirectory}/.config/waybar/themes/active.css";''
    + (import ./style.nix);
}

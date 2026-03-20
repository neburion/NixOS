{ pkgs, lib, ... }:

let
  themes = {
    dark       = import ../../themes/dark.nix;
    catppuccin = import ../../themes/catppuccin.nix;
    gruvbox    = import ../../themes/gruvbox.nix;
    everforest = import ../../themes/everforest.nix;
    nord       = import ../../themes/nord.nix;
  };

  inherit (import ./settings.nix { inherit lib; }) wofiArgs;

  wofi-power-menu     = import ./scripts/wofi-power-menu.nix     { inherit pkgs wofiArgs; };
  wofi-theme-switcher = import ./scripts/wofi-theme-switcher.nix { inherit pkgs wofiArgs; };
in
{
  imports = [ ./wofi.nix ];

  home.packages = [ wofi-power-menu wofi-theme-switcher ];

  xdg.configFile = lib.mapAttrs' (name: css:
    lib.nameValuePair "wofi/themes/${name}.css" { text = css; }
  ) themes;
}

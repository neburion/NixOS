{ ... }:

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

  activeTheme = themes.dark;
in
{
  imports = [
    ./config.nix
    ./scripts/current-power.nix
    ./scripts/power-toggle.nix
  ];

  programs.waybar.style = (mkWaybarTheme activeTheme) + (import ./style.nix);
}

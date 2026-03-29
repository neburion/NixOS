{ pkgs, lib, config, ... }:

let
  themes = {
    catppuccin = import ../../../themes/catppuccin.nix;
    dark       = import ../../../themes/dark.nix;
    everforest = import ../../../themes/everforest.nix;
    gruvbox    = import ../../../themes/gruvbox.nix;
    nord       = import ../../../themes/nord.nix;
  };

  # Generate wofi-specific CSS from a color attrset
  mkWofiTheme = c: ''
    #window { background-color: ${c.bg}; }
    #outer-box { padding: 10px; }
    #input {
        background-color: ${c.surface};
        color: ${c.fg};
        border-radius: 20px;
        padding: 12px;
    }
    #scroll { margin-top: 10px; margin-bottom: 10px; }
    #text { color: ${c.fg}; padding-left: 10px; }
    #text:selected { color: ${c.fg}; }
    #entry { padding: 5px; margin-top: 5px; }
    #entry:selected { background-color: ${c.selection}; }
    #input, #entry:selected { border-radius: 20px; border: 0px; }
  '';

  inherit (import ./shared-config.nix { inherit lib; }) wofiArgs;

  wofi-power-menu     = import ./scripts/wofi-power-menu.nix     { inherit pkgs wofiArgs; };
  wofi-theme-switcher = import ./scripts/wofi-theme-switcher.nix { inherit pkgs wofiArgs; homeDir = config.home.homeDirectory; };
in
{
  imports = [ ./config.nix ];

  home.packages = [ wofi-power-menu wofi-theme-switcher ];

  xdg.configFile = lib.mapAttrs' (name: colors:
    lib.nameValuePair "wofi/themes/${name}.css" { text = mkWofiTheme colors; }
  ) themes;
}

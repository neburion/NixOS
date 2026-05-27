{ pkgs, lib, config, ... }:

let
  themes = import ../../../themes;

  mkWofiTheme = c: ''
    #window { background-color: ${c.bg}; }
    #outer-box { padding: 10px; }
    #input {
        background-color: ${c.surface};
        color: ${c.fg};
        border-radius: 20px;
        border: 0px;
        padding: 12px;
    }
    #scroll { margin-top: 10px; margin-bottom: 10px; }
    #entry {
        padding: 8px;
        margin: 2px 0;
        border-radius: 20px;
        background-color: transparent;
    }
    #img { background-color: transparent; padding-right: 8px; }
    #text { color: ${c.fg}; background-color: transparent; padding-left: 4px; }
    /* Highlight the entire row (icon + text), not just the label. */
    #entry:selected { background-color: ${c.selection}; }
    #entry:selected #img,
    #entry:selected #text { background-color: transparent; color: ${c.fg}; }
  '';

  inherit (import ./shared-config.nix { inherit lib; }) wofiArgs;

  wofi-power-menu     = import ./scripts/wofi-power-menu.nix     { inherit pkgs wofiArgs; };
  wofi-theme-switcher = import ./scripts/wofi-theme-switcher.nix {
    inherit pkgs lib wofiArgs themes;
    homeDir = config.home.homeDirectory;
  };
in
{
  imports = [ ./config.nix ];

  home.packages = [ wofi-power-menu wofi-theme-switcher ];

  xdg.configFile = lib.mapAttrs' (name: colors:
    lib.nameValuePair "wofi/themes/${name}.css" { text = mkWofiTheme colors; }
  ) themes;
}

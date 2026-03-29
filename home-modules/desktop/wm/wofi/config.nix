{ lib, config, ... }:

let
  inherit (import ./shared-config.nix { inherit lib; }) sharedSettings;
in
{
  programs.wofi = {
    enable = true;
    settings = sharedSettings // {
      show          = "drun";
      term          = "ghostty";
      line_wrap     = "off";
      dynamic_lines = false;
      exec_search   = false;
      parse_search  = false;
      sort_order    = "default";
      filter_rate   = 100;
      key_expand    = "Tab";
      key_exit      = "Escape";
    };
    style = import ./style.nix { homeDir = config.home.homeDirectory; };
  };
}

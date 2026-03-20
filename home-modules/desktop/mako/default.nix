{ pkgs, lib, ... }:

let
  themes = {
    catppuccin = import ../../themes/catppuccin.nix;
    dark       = import ../../themes/dark.nix;
    everforest = import ../../themes/everforest.nix;
    gruvbox    = import ../../themes/gruvbox.nix;
    nord       = import ../../themes/nord.nix;
  };

  # Non-color settings shared across all themes
  baseConfig = ''
    font=FiraMono Nerd Font 11
    border-size=1
    border-radius=12
    width=300
    height=100
    margin=10
    padding=15
    default-timeout=5000
    sort=-time
    max-history=10
    max-visible=5
    ignore-timeout=0
    layer=overlay
    anchor=top-right
    text-alignment=left
    progress-color=over #89b4fa
    on-button-left=dismiss
    on-button-middle=none
    on-button-right=none
  '';

  mkMakoTheme = c: ''
    background-color=${c.bg}
    text-color=${c.fg}
    border-color=${c.surface}
  '';

  mkMakoConfig = c: baseConfig + (mkMakoTheme c);
in
{
  home.packages = with pkgs; [ libnotify ];

  services.mako.enable = true;

  # Write per-theme full configs
  xdg.configFile = lib.mapAttrs' (name: colors:
    lib.nameValuePair "mako/themes/${name}" { text = mkMakoConfig colors; }
  ) themes;
}

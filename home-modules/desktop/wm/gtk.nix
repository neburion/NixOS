{ pkgs, ... }:

let
  catppuccin-gtk = pkgs.catppuccin-gtk.override {
    accents = [ "blue" ];
    size    = "standard";
    variant = "mocha";
  };
in
{
  home.packages = with pkgs; [
    glib
    gnome-themes-extra
    catppuccin-gtk
    gruvbox-dark-gtk
    nordic
    everforest-gtk-theme
  ];

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  gtk = {
    enable = true;

    theme = {
      name    = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };

    iconTheme = {
      name    = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    font = {
      name = "FiraMono Nerd Font";
      size = 11;
    };
  };
}

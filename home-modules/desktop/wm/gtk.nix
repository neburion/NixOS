{ pkgs, lib, ... }:

let
  themes = import ../../themes;

  catppuccin-gtk = pkgs.catppuccin-gtk.override {
    accents = [ "blue" ];
    size    = "standard";
    variant = "mocha";
  };

  # Map theme name → gtk theme name, baked from palettes.
  gtkThemeMap = lib.mapAttrs (_: t: t.gtkTheme or "Adwaita-dark") themes;
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

  # Sync the GTK theme to whichever desktop theme is currently active.
  # Reads the active hyprland theme symlink so rebuilds don't clobber the user's choice.
  home.activation.syncGtkTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    HYPR_THEME="$HOME/.config/hypr/theme.conf"
    if [ -L "$HYPR_THEME" ]; then
      name=$(basename "$(readlink "$HYPR_THEME")" .conf)
      case "$name" in
        ${lib.concatStringsSep "\n        " (lib.mapAttrsToList (n: gtk:
          ''${n}) theme="${gtk}" ;;''
        ) gtkThemeMap)}
        *) theme="Adwaita-dark" ;;
      esac
      export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
      export XDG_RUNTIME_DIR="/run/user/$(id -u)"
      ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface gtk-theme "$theme" 2>/dev/null || true
    fi
  '';

  gtk = {
    enable = true;

    iconTheme = {
      name    = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    font = {
      name = "FiraMono Nerd Font";
      size = 11;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };
}

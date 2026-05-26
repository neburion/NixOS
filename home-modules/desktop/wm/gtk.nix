{ pkgs, lib, ... }:

let
  themes = import ../../themes;

  catppuccin-gtk = pkgs.catppuccin-gtk.override {
    accents = [ "blue" ];
    size    = "standard";
    variant = "mocha";
  };

  gtkThemeMap = lib.mapAttrs (_: t: t.gtkTheme or "Adwaita-dark") themes;

  # Hybrid icon theme: Adwaita file/folder icons + Papirus-Dark fallback for applet icons.
  # Adwaita icons look clean in Nautilus; Papirus-Dark covers anything Adwaita lacks in the tray.
  hybrid-icons = pkgs.runCommand "adwaita-papirus-hybrid-icons" {} ''
    mkdir -p $out/share/icons/Adwaita-Hybrid
    cat > $out/share/icons/Adwaita-Hybrid/index.theme << 'EOF'
[Icon Theme]
Name=Adwaita-Hybrid
Comment=Adwaita file icons, Papirus-Dark applet icons
Inherits=Adwaita,Papirus-Dark,hicolor
Directories=
EOF
  '';

  css = import ./gtk-css.nix { inherit pkgs lib themes; };

  gtk4CaseLines = lib.concatStringsSep "\n        " (lib.mapAttrsToList (n: f:
    ''${n}) gtk4_css="${f}" ;;''
  ) css.gtk4Files);

  gtk3CaseLines = lib.concatStringsSep "\n        " (lib.mapAttrsToList (n: f:
    ''${n}) gtk3_css="${f}" ;;''
  ) css.gtk3Files);

  gtkCaseLines = lib.concatStringsSep "\n        " (lib.mapAttrsToList (n: gtk:
    ''${n}) theme="${gtk}" ;;''
  ) gtkThemeMap);
in
{
  home.packages = with pkgs; [
    glib
    gnome-themes-extra
    catppuccin-gtk
    gruvbox-dark-gtk
    nordic
    everforest-gtk-theme
    adwaita-icon-theme
  ];

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  home.activation.syncGtkTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    HYPR_THEME="$HOME/.config/hypr/theme.conf"
    if [ -L "$HYPR_THEME" ]; then
      name=$(basename "$(readlink "$HYPR_THEME")" .conf)
      gtk4_css=""
      gtk3_css=""
      theme="Adwaita-dark"
      case "$name" in
        ${gtk4CaseLines}
        *) ;;
      esac
      case "$name" in
        ${gtk3CaseLines}
        *) ;;
      esac
      case "$name" in
        ${gtkCaseLines}
        *) ;;
      esac
      export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
      export XDG_RUNTIME_DIR="/run/user/$(id -u)"
      ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface gtk-theme "$theme" 2>/dev/null || true
      if [ -n "$gtk4_css" ]; then
        mkdir -p "$HOME/.config/gtk-4.0"
        cp "$gtk4_css" "$HOME/.config/gtk-4.0/gtk.css"
      fi
      if [ -n "$gtk3_css" ]; then
        mkdir -p "$HOME/.config/gtk-3.0"
        cp "$gtk3_css" "$HOME/.config/gtk-3.0/gtk.css"
      fi
    fi
  '';

  gtk = {
    enable = true;

    iconTheme = {
      name    = "Adwaita-Hybrid";
      package = hybrid-icons;
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

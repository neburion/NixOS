{ pkgs, ... }:

# Same hybrid icon theme as the clean preset — Adwaita's file and folder icons
# read better in Nautilus, Papirus-Dark covers what Adwaita lacks in the tray.
# The font is the difference: Inter, matching the shell, instead of a
# monospace face.

let
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
in
{
  gtk = {
    enable = true;

    theme = {
      name    = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };

    iconTheme = {
      name    = "Adwaita-Hybrid";
      package = hybrid-icons;
    };

    font = {
      name = "Inter";
      size = 11;
    };

    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };
}

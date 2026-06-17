{ pkgs, ... }:

let
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
in
{
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

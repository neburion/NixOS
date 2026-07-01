{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nautilus
  ];

  xdg.mimeApps.defaultApplications = {
    "inode/directory" = "org.gnome.Nautilus.desktop";
  };
}

{ pkgs, ... }:

{
  home.packages = with pkgs; [
    loupe       # image viewer
    celluloid   # video player
    spotify     # music
    obs-studio  # recording / streaming
  ];

  xdg.mimeApps.defaultApplications = {
    "image/png"     = "org.gnome.Loupe.desktop";
    "image/jpeg"    = "org.gnome.Loupe.desktop";
    "image/gif"     = "org.gnome.Loupe.desktop";
    "image/webp"    = "org.gnome.Loupe.desktop";
    "image/svg+xml" = "org.gnome.Loupe.desktop";
  };
}

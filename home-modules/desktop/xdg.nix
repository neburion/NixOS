{ config, ... }:

{
  xdg.mimeApps.enable = true;

  # xdg.userDirs writes ~/.config/user-dirs.dirs, which would otherwise
  # collide with the existing read-only home-manager symlink.
  xdg.configFile."user-dirs.dirs".force = true;

  xdg.userDirs = {
    enable = true;
    createDirectories = false;
    documents  = "${config.home.homeDirectory}/Docs";
    download   = "${config.home.homeDirectory}/Downloads";
    pictures   = "${config.home.homeDirectory}/Media/Image";
    videos     = "${config.home.homeDirectory}/Media/Video";
    music      = "${config.home.homeDirectory}/Media/Music";
    desktop    = "${config.home.homeDirectory}/.local/share/desktop";
    templates  = "${config.home.homeDirectory}/.local/share/templates";
    publicShare = "${config.home.homeDirectory}/.local/share/public";
  };
}

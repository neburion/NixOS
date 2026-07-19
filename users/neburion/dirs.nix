{ ... }:

# neburion's home-directory layout.
# - `systemd.user.tmpfiles.rules` creates the physical directories at
#   session start (NixOS scope, applies to this user's user-systemd).
# - `xdg.userDirs` (reached via `home-manager.users.neburion.*`) writes
#   ~/.config/user-dirs.dirs so XDG-aware apps (Nautilus sidebar, GTK
#   file pickers, screenshot tools respecting $XDG_PICTURES_DIR, etc.)
#   route the standard names to this custom layout instead of the stock
#   ~/Documents ~/Downloads ~/Music ~/Pictures ~/Videos.

let
  home = "/home/neburion";

  dirs = [
    "Docs"
    "Downloads"
    "Media"
    "Media/Image"
    "Media/Image/Screenshot"
    "Media/Video"
    "Media/Music"
    "Media/Wallpapers"
    "Media/Wallpapers/Catppuccin"
    "Media/Wallpapers/Dark"
    "Media/Wallpapers/Everforest"
    "Media/Wallpapers/Gruvbox"
    "Media/Wallpapers/Nord"
    "Projects"
    "Projects/Dev"
    "Projects/Art"
    "Projects/Tower"
    "Gaming"
  ];
in
{
  systemd.user.tmpfiles.rules = map (d: "d %h/${d} 0755 - - -") dirs;

  home-manager.users.neburion.xdg.userDirs = {
    enable               = true;
    createDirectories    = false;
    setSessionVariables  = true;

    documents   = "${home}/Docs";
    download    = "${home}/Downloads";
    music       = "${home}/Media/Music";
    pictures    = "${home}/Media/Image";
    videos      = "${home}/Media/Video";

    desktop     = null;
    templates   = null;
    publicShare = null;
  };
}

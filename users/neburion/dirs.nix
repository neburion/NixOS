{ ... }:

# neburion's home-directory layout.
# - `systemd.user.tmpfiles.rules` creates the physical directories at
#   session start (NixOS scope, applies to this user's user-systemd).
# - `xdg.userDirs` (reached via `home-manager.users.neburion.*`) writes
#   ~/.config/user-dirs.dirs so XDG-aware apps (Nautilus sidebar, GTK
#   file pickers, screenshot tools respecting $XDG_PICTURES_DIR, etc.)
#   route the standard names to this custom layout instead of the stock
#   ~/Documents ~/Downloads ~/Music ~/Pictures ~/Videos.
# - `backup.paths.neburion` declares which of these get nightly R2 backup
#   via modules/system/backup/restic.nix. Only "irreplaceable" dirs — no
#   Downloads, no caches, no gaming installs.

let
  home = "/home/neburion";

  dirs = [
    "Docs"
    "Downloads"
    "Passwords"
    "Media"
    "Media/Image"
    "Media/Image/Screenshot"
    "Media/Video"
    "Media/Music"
    "Media/Books"
    "Media/Wallpapers"

    # Only the root. Wallpapers is a git checkout, and its shape is the
    # repo's business — no row here may name anything inside it.
    #
    # It has held two layouts already: five per-theme folders (Catppuccin,
    # Dark, Gruvbox, …), then a second level of folders under each
    # orientation. Both were listed here, and both outlived the layout they
    # matched, so every login recreated a dozen empty directories the library
    # no longer used — and an empty directory is indistinguishable from one
    # whose contents you meant to keep. This file is deliberately no longer in
    # a position to have an opinion about it.

    "Projects"
    "Projects/Dev"
    "Projects/Art"
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

  backup.paths.neburion = [
    "${home}/Docs"
    "${home}/Projects"
    "${home}/Passwords"
    "${home}/Media/Books"
  ];
}

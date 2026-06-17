{ ... }:

{
  systemd.user.tmpfiles.rules = map (d: "d %h/${d} 0755 - - -") [
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
}

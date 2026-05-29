{ ... }:

{
  systemd.user.tmpfiles.rules = [
    "d %h/Docs                              0755 - - -"
    "d %h/Downloads                         0755 - - -"
    "d %h/Media                             0755 - - -"
    "d %h/Media/Image                       0755 - - -"
    "d %h/Media/Image/Screenshot            0755 - - -"
    "d %h/Media/Video                       0755 - - -"
    "d %h/Media/Music                       0755 - - -"
    "d %h/Media/Wallpapers                  0755 - - -"
    "d %h/Media/Wallpapers/Catppuccin       0755 - - -"
    "d %h/Media/Wallpapers/Dark             0755 - - -"
    "d %h/Media/Wallpapers/Everforest       0755 - - -"
    "d %h/Media/Wallpapers/Gruvbox          0755 - - -"
    "d %h/Media/Wallpapers/Nord             0755 - - -"
    "d %h/Projects                          0755 - - -"
    "d %h/Projects/Dev                      0755 - - -"
    "d %h/Projects/Art                      0755 - - -"
    "d %h/Projects/Tower                    0755 - - -"
  ];
}

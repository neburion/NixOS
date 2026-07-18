{ ... }:

# NieR wallpapers seed the WallpaperPicker directory; nier-arrow.png is the
# chevron sprite used by ControlCenter's radial navigation.

{
  xdg.configFile."quickshell/assets/nier-arrow.png".source = ./assets/nier-arrow.png;

  home.file = {
    "Pictures/wallpapers/UDqXyQq.jpeg".source     = ./assets/wallpapers/UDqXyQq.jpeg;
    "Pictures/wallpapers/2b.jpg".source           = ./assets/wallpapers/2b.jpg;
    "Pictures/wallpapers/hollow-knight.jpg".source = ./assets/wallpapers/hollow-knight.jpg;
    "Pictures/wallpapers/nier-city.jpg".source    = ./assets/wallpapers/nier-city.jpg;
  };
}

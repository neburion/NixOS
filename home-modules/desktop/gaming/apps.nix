{ pkgs, ... }:

{
  home.packages = with pkgs; [
    spotify    # Music
    obs-studio # Recording/streaming
  ];
}

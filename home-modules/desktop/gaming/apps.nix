{ pkgs, ... }:

{
  home.packages = with pkgs; [
    vesktop    # Discord client
    spotify    # Music
    obs-studio # Recording/streaming
  ];
}

{ pkgs, ... }:

{
  gamingLauncher.enable = true;

  home.packages = with pkgs; [
    heroic        # GOG/Epic launcher
    prismlauncher # Minecraft launcher
    spotify       # Music
    obs-studio    # Recording/streaming
  ];
}

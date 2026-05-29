{ pkgs, ... }:

{
  imports = [
    ./apps.nix
  ];

  gamingLauncher.enable = true;

  home.packages = with pkgs; [
    heroic        # GOG/Epic launcher
    prismlauncher # Minecraft launcher
  ];
}

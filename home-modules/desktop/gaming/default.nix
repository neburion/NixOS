{ pkgs, ... }:

{
  imports = [
    ./apps.nix
    ./hyprland.nix
    ./backup.nix
  ];

  home.packages = with pkgs; [
    heroic        # GOG/Epic launcher
    prismlauncher # Minecraft launcher
  ];
}

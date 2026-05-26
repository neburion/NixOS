{ pkgs, ... }:

{
  imports = [
    ./apps.nix
    ./hyprland.nix
  ];

  home.packages = with pkgs; [
    heroic        # GOG/Epic launcher
    prismlauncher # Minecraft launcher
  ];
}

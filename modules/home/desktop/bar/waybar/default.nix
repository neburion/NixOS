{ ... }:

{
  imports = [
    ./config.nix
    ./style.nix
    ./themes.nix
    ./tray-apps
    ./scripts/current-power.nix
    ./scripts/power-toggle.nix
  ];
}

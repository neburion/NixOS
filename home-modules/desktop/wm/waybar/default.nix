{ ... }:

{
  imports = [
    ./config.nix
    ./scripts/current-power.nix
    ./scripts/power-toggle.nix
    ./style.nix
    ./themes.nix
  ];
}

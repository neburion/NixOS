{ ... }:
{
  imports = [
    ./home-modules/desktop
    ./home-modules/terminal
    ./home-modules/dev
    ./home-modules/gaming
  ];

  nixpkgs.config.allowUnfree = true; # allow unfree packages
  home.stateVersion = "25.11";
}

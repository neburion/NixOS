{ ... }:

# Everything gaming: the stores and launchers, the emulator, and the one game
# installed declaratively.
#
# steam/ is only its system half — programs.steam.enable — so it is imported by
# the host, not here. A preset in modules/home cannot enable a NixOS option.

{
  imports = [
    ../gaming/launchers/bb-launcher
    ../gaming/launchers/heroic.nix
    ../gaming/launchers/prism-launcher.nix
    ../gaming/launchers/sober.nix
    ../gaming/emulators/shadps4.nix
    ../gaming/games/osu.nix
  ];
}

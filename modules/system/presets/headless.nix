{ ... }:

# A box with no one sitting at it: never sleeps, and drops you at a shell on
# tty1 because the only reason to open its lid is to diagnose something.

{
  imports = [
    ../core/console.nix
    ../hardware/always-on.nix
    ../hardware/power-profiles.nix
  ];
}

{ ... }:

# Everything the live USB needs. Imported only by hosts/installer.
#
# Self-contained by necessity. The installer host deliberately bypasses
# mkSystem — no specialArgs, no home-manager, no overlays — so nothing here may
# import modules/system/ or assume `inputs`. That is why nix-experimental.nix
# restates the one nix setting it needs instead of importing core/nix.nix, and
# why nixinstall/nixshrink carry their own runtimeInputs.

{
  imports = [
    ./nix-experimental.nix
    ./serial-console.nix
    ./nixinstall.nix
    ./nixshrink.nix
  ];
}

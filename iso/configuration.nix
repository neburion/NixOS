{ modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ./nix-experimental.nix
    ./packages.nix
    ./serial-console.nix
    ./nixflash.nix
    ./scripts
  ];
}

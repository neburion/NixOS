{ modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ./nix-experimental.nix
    ./packages
    ./scripts
    ./serial-console.nix
  ];
}

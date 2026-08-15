{ modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ./nix-experimental.nix
    ./serial-console.nix
    ./scripts
  ];
}

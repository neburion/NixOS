{ ... }:

{
  imports = [
    ./networkmanager.nix
    ./ssh.nix
    ./localsend.nix
    ./syncthing.nix
  ];
}

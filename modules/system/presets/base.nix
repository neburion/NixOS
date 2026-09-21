{ ... }:

# What every host in the fleet gets, whatever it is for.

{
  imports = [
    ../core/nix.nix
    ../core/locale.nix
    ../core/sops.nix
    ../core/sudo.nix
    ../network/networkmanager.nix
    ../network/ssh.nix
    ../services/fleet-status
    ../../tools/fleet/hooks.nix
  ];
}

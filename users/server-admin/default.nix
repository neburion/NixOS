{ ... }:

# Imports only. See users/neburion/default.nix for why the system-level fish
# module is not imported from here — the host owns that.

{
  imports = [
    ./account.nix
    ./home.nix
  ];
}

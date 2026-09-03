{ ... }:

# Imports only. The system-level `programs.fish.enable` that this account's
# login shell needs is NOT imported here — a user directory reaching into
# modules/system/ crosses the layer boundary the whole model rests on
# (DESIGN.md L5). The host that gives this user an account imports
# modules/system/core/fish.nix instead.

{
  imports = [
    ./account.nix
    ./dirs.nix
    ./home.nix
  ];
}

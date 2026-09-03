{ ... }:

# What pod042 has been asked to do. Would change if you kept the machine and
# changed its job — or moved it to a different house, in wifi's case.

{
  imports = [
    ./cloudflare.nix
    ./wifi.nix
  ];
}

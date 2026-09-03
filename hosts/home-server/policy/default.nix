{ ... }:

# What home-server has been asked to do. Family-facing: print and scan, and
# the tunnel that exposes it.

{
  imports = [
    ./cloudflare.nix
    ./wifi.nix
  ];
}

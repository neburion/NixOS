{ ... }:

# What personal-server has been asked to do: which repos it deploys, what gets
# snapshotted nightly, which hostnames it answers to.

{
  imports = [
    ./apps.nix
    ./backup.nix
    ./cloudflare.nix
    ./wifi.nix
  ];
}

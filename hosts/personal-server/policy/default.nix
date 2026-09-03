{ ... }:

# What this box has been asked to do. Both entries are genuine per-host
# choices: which repos it deploys, and what gets snapshotted nightly.
#
# cloudflare.nix used to sit here too and held an empty attrset — the four
# tunnels this host runs are declared by the services that need them, which is
# where a tunnel belongs. wifi.nix was here as well, on all three hosts, with
# the same network in each; it is one module now.

{
  imports = [
    ./apps.nix
    ./backup.nix
  ];
}

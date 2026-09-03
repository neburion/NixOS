{ ... }:

# What pod042 physically is. Would change if you swapped the machine but kept
# its job.
#
# ./disk.nix is deliberately NOT imported. It is a disko declaration, and
# importing it on a running machine hands disko the authority to repartition
# this disk. It exists for a fresh install only, where nixinstall.sh evaluates
# it directly. Do not uncomment it.

{
  imports = [
    ./backlight.nix
    ./displays.nix
    ./gpu.nix
  ];
}

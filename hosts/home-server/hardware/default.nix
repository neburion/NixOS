{ ... }:

# What home-server physically is.
#
# Empty on purpose. The only physical fact this box declares is its disk
# layout, and ./disk.nix is deliberately NOT imported: it is a disko
# declaration, and importing it on a running machine hands disko the authority
# to repartition the disk. It exists for a fresh install only, where
# nixinstall.sh evaluates it directly by path. Do not uncomment it.
#
# The directory and this file stay so every host has the same shape, and so
# the warning above has somewhere to live.

{
  imports = [ ];
}

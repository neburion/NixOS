{ ... }:

# The tailnet: the daemon, and the host→address map that makes bare hostnames
# resolve.
#
# A module rather than two files, because hosts.nix is meaningless on its own —
# it is a list of addresses on a network this machine is not joined to. Every
# host that takes one takes the other.

{
  imports = [
    ./tailscale.nix
    ./hosts.nix
  ];
}

{ ... }:

# Join the fleet tailnet. Bare hostnames resolve from anywhere after this, so
# `rebuild <host>` works regardless of the physical network the target is on.

{
  imports = [ ../network/tailscale ];
}

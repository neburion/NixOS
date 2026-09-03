{ ... }:

# Opens LAN ports for LocalSend peer discovery + transfer.
# Pair with the home-side app install: modules/home/apps/localsend.nix
# in the user's home.nix. Without both halves LocalSend either can't
# be launched (no binary) or can't see peers (no firewall hole).

{
  networking.firewall = {
    allowedTCPPorts = [ 53317 ];
    allowedUDPPorts = [ 53317 ];
  };
}

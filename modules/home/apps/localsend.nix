{ pkgs, ... }:

# Installs the LocalSend GUI. Requires the firewall side to be present:
# import modules/system/networking/localsend-firewall.nix in the host's
# configuration.nix, otherwise LAN peer discovery silently fails.

{
  home.packages = with pkgs; [
    localsend
  ];
}

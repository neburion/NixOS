{ ... }:

# NetworkManager + fleet-wide DNS.
#
# `insertNameservers` prepends Cloudflare 1.1.1.1/1.0.0.1 to whatever
# nameservers the DHCP lease provides. Reason: Bell HH3000's built-in
# resolver (192.168.2.1) silently drops external queries — see the
# project_bell_hh3000 quirk log. Prepending a reliable public resolver
# means the OS tries CF first and never falls back to the broken Bell one.
#
# Applies fleet-wide. Hosts on non-Bell networks are unaffected (using
# 1.1.1.1 first is fine anywhere).

{
  networking.networkmanager.enable = true;
  networking.networkmanager.insertNameservers = [ "1.1.1.1" "1.0.0.1" ];
}

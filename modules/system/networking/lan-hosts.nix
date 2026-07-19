{ ... }:

# Static /etc/hosts entries for well-known devices on the home LAN.
# Preferred over relying on mDNS/`.local` because glibc's search-suffix
# logic only routes through DNS, not mDNS — so `ssh printer` (bare name)
# doesn't reach avahi even when `.local` is in the search list. A hosts
# entry hits the `files` NSS source before DNS is even asked.
#
# IPs are stable because they're DHCP-reserved on the router. Update this
# file if a reservation changes.

{
  networking.hosts = {
    "192.168.2.164" = [ "printer" "print-server" ];
  };
}

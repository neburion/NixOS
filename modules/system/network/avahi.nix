{ ... }:

# mDNS client + responder. Lets this host resolve `.local` hostnames
# (via glibc NSS integration `nssmdns4`) and advertise its own hostname
# on the LAN. `openFirewall = true` is important — without a firewall
# hole for UDP 5353, incoming mDNS replies from other hosts get dropped
# even if avahi is running.

{
  services.avahi = {
    enable       = true;
    nssmdns4     = true;
    openFirewall = true;
  };
}

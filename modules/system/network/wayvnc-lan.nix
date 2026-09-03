{ ... }:

# LAN access for wayvnc (used by the phone-as-display toggle):
#   1. Opens TCP 5900 so remote VNC clients can reach wayvnc.
#   2. Enables avahi user-service publishing so the toggle script's
#      `avahi-publish-service _rfb._tcp 5900` call succeeds and phone VNC
#      apps discover the server by scan instead of manual IP entry.
# Pair with the home-side module: modules/home/desktop/remote-display/wayvnc.nix.

{
  networking.firewall.allowedTCPPorts = [ 5900 ];

  services.avahi = {
    publish = {
      enable       = true;
      userServices = true;
    };
    # wayvnc binds 0.0.0.0 (IPv4 only). If avahi advertises both v4 and v6,
    # phone VNC apps try IPv6 link-local first and hang for 20s because
    # nothing is listening there. Force IPv4-only advertisement.
    ipv6 = false;
  };
}

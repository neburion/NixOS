{ ... }:

# LAN access for wayvnc (used by the phone-as-display toggle).
#
# Deliberately NOT scoped to tailscale0 the way ssh.nix / web-ui.nix /
# app-platform are. The phone should be able to connect over plain LAN on
# networks that permit client-to-client traffic, without needing the
# Tailscale app running. The listener is view-only (--disable-input) and is
# only up while the toggle is on, so the exposure is a read-only framebuffer
# for the length of a deliberate session.
#
# No avahi _rfb._tcp advertisement: mDNS does not cross this house's Plume
# pods (separate bridge domains) and never crosses Tailscale at all, so
# service discovery was advertising into the void. The notification prints
# the addresses instead.
{
  networking.firewall.allowedTCPPorts = [ 5900 ];
}

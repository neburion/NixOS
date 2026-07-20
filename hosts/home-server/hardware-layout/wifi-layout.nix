{ ... }:

# Bell HH3000 auto-blocklists any LAN MAC that the router's
# "Manually specify DNS" points at (well-documented HH3000 quirk +
# separately confirmed here twice, on 2026-07-20). The block persists
# across router reboots and DNS-setting reverts; only clearing paths
# are (a) power-cycling the modem or (b) presenting a fresh MAC.
#
# We ship Plan B (AdGuard-as-DHCP), which requires Bell's DNS setting
# to stay on Automatic forever — so the block trigger never fires
# again after this. This MAC is the third and hopefully final one:
# a locally-administered unicast address (LAA bit set) with no vendor
# OUI, no collision risk with real hardware.
{
  networking.networkmanager.ensureProfiles.profiles.home = {
    connection    = { id = "BELL096"; type = "wifi"; };
    wifi          = {
      mode = "infrastructure";
      ssid = "BELL096";
      cloned-mac-address = "5A:C4:9A:A9:AD:FB";
    };
    wifi-security = { key-mgmt = "wpa-psk"; psk = "9FCC749DC624"; };

    ipv4.method = "auto";
    ipv6.method = "auto";
  };
}

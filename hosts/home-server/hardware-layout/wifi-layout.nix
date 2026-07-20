{ ... }:

# Bell HH3000 permanently blocklisted this box's real wifi MAC
# (F8:DA:0C:3D:41:D5) during a 2026-07-20 debug session: setting the
# router's "Manually specify DNS" to a LAN IP is a well-documented
# HH3000 quirk that auto-blocks that MAC. The block persists across
# router reboots and even after reverting the DNS setting.
#
# We present a locally-administered MAC (LAA bit set, no vendor OUI)
# so Bell sees a "new" device. Reverting to the real MAC would put
# this box right back on the blocklist and it'd lose all WAN traffic.
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

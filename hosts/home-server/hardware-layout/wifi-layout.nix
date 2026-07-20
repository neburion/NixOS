{ ... }:

# Bell HH3000 auto-blocklisted this box's permanent wifi MAC
# (F8:DA:0C:3D:41:D5) — router silently dropped all its traffic and
# stopped answering ARP. Cause was almost certainly the router's
# "Manually specify DNS" pointing at 192.168.2.164 (this box), which
# some Bell firmwares treat as a security anomaly. The block persists
# across router reboots, so we present a different MAC on every wifi
# association from this box's side and let Bell see us as a "new"
# device. The chosen MAC is a locally-administered unicast address
# (LAA bit set) with no vendor OUI, so it can't collide with a real
# device.
{
  networking.networkmanager.ensureProfiles.profiles.home = {
    connection    = { id = "BELL096"; type = "wifi"; };
    wifi          = {
      mode = "infrastructure";
      ssid = "BELL096";
      cloned-mac-address = "0E:1E:57:A1:D9:11";
    };
    wifi-security = { key-mgmt = "wpa-psk"; psk = "9FCC749DC624"; };
    ipv4.method   = "auto";
    ipv6.method   = "auto";
  };
}

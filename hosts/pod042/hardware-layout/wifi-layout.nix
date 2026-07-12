{ ... }:

{
  networking.networkmanager.ensureProfiles.profiles.home = {
    connection    = { id = "BELL096"; type = "wifi"; };
    wifi          = { mode = "infrastructure"; ssid = "BELL096"; };
    wifi-security = { key-mgmt = "wpa-psk"; psk = "9FCC749DC624"; };
    ipv4.method   = "auto";
    ipv6.method   = "auto";
  };
}

{ ... }:

# Home wifi, so the box comes up on the network unattended after a reboot.
#
# This host is meant to travel, and NetworkManager keeps any profile added
# at runtime with `nmcli`/`nmtui` — but only in /etc/NetworkManager, which
# isn't declarative. Networks worth surviving a reinstall belong here as
# additional `ensureProfiles.profiles.<name>` entries.
#
# PSK in plaintext is intentional; see "Known security debt" in ARCHITECTURE.md.

{
  networking.networkmanager.ensureProfiles.profiles.home = {
    connection    = { id = "BELL096"; type = "wifi"; };
    wifi          = {
      mode = "infrastructure";
      ssid = "BELL096";
    };
    wifi-security = { key-mgmt = "wpa-psk"; psk = "9FCC749DC624"; };

    ipv4.method = "auto";
    ipv6.method = "auto";
  };
}

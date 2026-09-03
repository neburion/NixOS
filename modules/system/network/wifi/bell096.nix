{ ... }:

# Home wifi, so a box comes up on the network unattended after a reboot — and
# so the installer ISO is already online before you touch nmtui.
#
# One file per network. Import the ones a host should know; a machine that
# travels can carry several. NetworkManager keeps any profile added at runtime
# with nmcli/nmtui, but only in /etc/NetworkManager, which is not declarative —
# a network worth surviving a reinstall belongs here as its own file.
#
# The PSK is plaintext on purpose. It is a wifi password.

{
  networking.networkmanager.ensureProfiles.profiles.bell096 = {
    connection = {
      id   = "BELL096";
      type = "wifi";
    };

    wifi = {
      mode = "infrastructure";
      ssid = "BELL096";
    };

    wifi-security = {
      key-mgmt = "wpa-psk";
      psk      = "9FCC749DC624";
    };

    ipv4.method = "auto";
    ipv6.method = "auto";
  };
}

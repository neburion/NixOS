{ pkgs, ... }:

# `logitech-battery` — one line per paired device with a charge reading:
#
#     74 discharging PRO X Wireless
#
# Exits 1 when nothing answered, so a caller can treat silence as absence
# instead of parsing an empty string.
#
# Why a solaar wrapper and not sysfs: hid-logitech-hidpp owns the battery for
# these mice, but its device table lists the mouse's own USB id (C094, the
# cable) and not the Lightspeed receiver (C547). Over the dongle the receiver
# falls through to hid-generic, no power_supply node is ever created, and
# /sys/class/power_supply holds only the laptop's own cells. HID++ over
# hidraw is the only route, and solaar is the thing that already speaks it.
#
# It costs ~5s per call — a Python start plus a full feature enumeration of
# every paired device. Poll it in minutes, never in seconds.

{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "logitech-battery";
      runtimeInputs = with pkgs; [ solaar gawk ];
      text = ''
        # solaar prints a block per device: an indented "N: NAME" line, then
        # its features. Battery lives under whichever name was last seen.
        report=$(solaar show 2>/dev/null | awk '
          /^  [0-9]+: / { name = substr($0, index($0, ": ") + 2); next }

          /Battery: [0-9]+%/ {
            # A device can list both UNIFIED BATTERY and a legacy battery
            # feature, which prints the same reading twice.
            if (name == "" || seen[name]++) next

            match($0, /Battery: [0-9]+%/)
            pct = substr($0, RSTART + 9, RLENGTH - 10)

            state = "unknown"
            if (match($0, /BatteryStatus\.[A-Z_]+/))
              state = tolower(substr($0, RSTART + 14, RLENGTH - 14))

            print pct, state, name
          }
        ') || true

        [ -n "$report" ] || exit 1
        printf '%s\n' "$report"
      '';
    })
  ];
}

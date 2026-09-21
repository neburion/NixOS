{ ... }:

# The machine's own cell, straight off sysfs. Outermost ring, because it is
# the one that decides whether the session survives.
#
# It is also the ring that carries the power profile's colour rather than the
# wallpaper accent — green idling, amber working, red and alight on
# performance. That spends its low-battery colour, so the number beside the
# dial is what goes critical instead.

{
  quickshell.services.LaptopBattery = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        property int    capacity: 0
        property string status:   "Unknown"
        readonly property bool present:  capacity > 0
        readonly property bool charging: status === "Charging" || status === "Full"

        FileView {
            id: cap
            path: "/sys/class/power_supply/BAT0/capacity"
            watchChanges: false
            onLoaded: {
                var n = parseInt(text().trim(), 10);
                if (!isNaN(n)) root.capacity = n;
            }
        }
        FileView {
            id: stat
            path: "/sys/class/power_supply/BAT0/status"
            watchChanges: false
            onLoaded: root.status = text().trim()
        }

        function refresh() { cap.reload(); stat.reload(); }

        Timer {
            interval: 15000; running: true; triggeredOnStart: true; repeat: true
            onTriggered: root.refresh()
        }
    }
  '';

  quickshell.powerSources.laptop = {
    order = 10;
    reading = ''
      ({
          label:   "Laptop",
          present: LaptopBattery.present,
          value:   LaptopBattery.capacity,
          caption: LaptopBattery.charging ? "Charging" : "Discharging",
          color:   PowerProfile.tint,
          burning: PowerProfile.burning
      })
    '';
    refresh = "LaptopBattery.refresh();";
  };
}

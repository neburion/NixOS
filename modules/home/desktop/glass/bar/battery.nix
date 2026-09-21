{ ... }:

# Battery: the sysfs service, and nothing else. The widget that used to live
# here is gone — the laptop's cell is the outer ring of the dial in power.nix
# now, drawn beside the two it shares a machine with rather than beside the
# CPU and RAM percentages it has nothing to do with.

{
  quickshell.services.Battery = ''
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

        Timer {
            interval: 15000
            running: true
            triggeredOnStart: true
            repeat: true
            onTriggered: { cap.reload(); stat.reload(); }
        }
    }
  '';
}

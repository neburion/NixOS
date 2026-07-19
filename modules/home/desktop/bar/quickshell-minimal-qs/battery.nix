{ ... }:

# Battery: sysfs service + bar widget. Self-contained — importing this file
# is all that's needed for battery display.

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

  quickshell.modules.BarBattery = ''
    import QtQuick
    import "../Common"
    import "../Services"

    Text {
        id: root
        visible: Battery.present

        readonly property string glyph:
            !Battery.present       ? "" :
            Battery.capacity >= 95 ? "󰁹" :
            Battery.capacity >= 85 ? "󰂂" :
            Battery.capacity >= 75 ? "󰂁" :
            Battery.capacity >= 65 ? "󰂀" :
            Battery.capacity >= 55 ? "󰁿" :
            Battery.capacity >= 45 ? "󰁾" :
            Battery.capacity >= 35 ? "󰁽" :
            Battery.capacity >= 25 ? "󰁼" :
            Battery.capacity >= 15 ? "󰁻" :
                                     "󰁺"

        font.family: "FiraMono Nerd Font"
        font.pixelSize: 19
        font.weight: Font.Black
        color: Battery.capacity <= 20 && !Battery.charging ? Theme.warning : Theme.fg
        text: root.glyph + " " + Battery.capacity + "%"
    }
  '';
}

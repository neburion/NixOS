{ ... }:

# Battery: sysfs service + widget. The service is the clean one verbatim; only
# the widget changed. Charging is the one state that takes the accent — it is
# the definition of "live".

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
    import "../Services"
    import "../Common"

    Row {
        id: root
        visible: Battery.present
        spacing: 6

        property color accent: Glass.accentFallback

        readonly property bool low: Battery.capacity <= 15 && !Battery.charging

        Text {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            font.family: Glass.fontIcon
            font.pixelSize: 15
            font.variableAxes: Battery.charging ? Glass.iconActive : Glass.iconIdle
            color: root.low          ? Glass.critical
                 : Battery.charging  ? root.accent
                 :                     Glass.muted
            // battery_charging_full, else the bar series stepped by capacity
            readonly property string bars:
                  Battery.capacity >= 95 ? ""
                : Battery.capacity >= 82 ? ""
                : Battery.capacity >= 68 ? ""
                : Battery.capacity >= 54 ? ""
                : Battery.capacity >= 40 ? ""
                : Battery.capacity >= 26 ? ""
                : Battery.capacity >= 12 ? ""
                :                          ""

            text: Battery.charging ? "" : glyph.bars

            Behavior on color { ColorAnimation { duration: 220 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            font.family: Glass.fontUi
            font.pixelSize: 12
            font.features: Glass.tnum
            color: root.low ? Glass.critical : Glass.muted
            text:  Battery.capacity + "%"
        }
    }
  '';
}

{ pkgs, ... }:

# PowerProfile service + clickable power-toggle widget. Self-contained.

{
  quickshell.services.PowerProfile = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import Quickshell.Hyprland
    import QtQuick

    Singleton {
        id: root

        property string current: "balanced"

        Process {
            id: getProfile
            command: [ "${pkgs.power-profiles-daemon}/bin/powerprofilesctl", "get" ]
            running: false
            stdout: StdioCollector {
                onStreamFinished: root.current = text.trim()
            }
        }

        Process {
            id: setProfile
            running: false
        }

        function refresh() { getProfile.running = true; }

        function cycle() {
            var next;
            if (root.current === "performance")      next = "power-saver";
            else if (root.current === "power-saver") next = "balanced";
            else                                     next = "performance";
            setProfile.command = [ "${pkgs.power-profiles-daemon}/bin/powerprofilesctl", "set", next ];
            setProfile.running = true;
            root.current = next;
            Hyprland.dispatch("keyword misc:vfr " + (next === "performance" ? 0 : 1));
        }

        Timer {
            interval: 10000
            running: true
            triggeredOnStart: true
            repeat: true
            onTriggered: root.refresh()
        }
    }
  '';

  quickshell.modules.BarPowerToggle = ''
    import QtQuick
    import "../Common"
    import "../Services"

    Rectangle {
        id: root
        color: Theme.surface
        radius: 5
        implicitHeight: 28
        implicitWidth: label.implicitWidth + 10

        readonly property string glyph:
            PowerProfile.current === "performance" ? "󰈸" :
            PowerProfile.current === "power-saver" ? "" :
            "󰾞"

        readonly property string labelText:
            PowerProfile.current === "performance" ? "Perf" :
            PowerProfile.current === "power-saver" ? "Eco" :
            "Balance"

        Text {
            id: label
            anchors.centerIn: parent
            font.family: "FiraMono Nerd Font"
            font.pixelSize: 19
            font.weight: Font.Black
            color: Theme.fg
            text: root.glyph + " " + root.labelText
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: PowerProfile.cycle()
        }
    }
  '';
}

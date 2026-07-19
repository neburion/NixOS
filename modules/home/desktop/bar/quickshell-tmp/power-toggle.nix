{ pkgs, ... }:

# PowerProfile service + power toggle. Sepia text, no capsule.

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
            stdout: StdioCollector { onStreamFinished: root.current = text.trim() }
        }

        Process { id: setProfile; running: false }

        function refresh() { getProfile.running = true; }

        function cycle() {
            var next = root.current === "performance" ? "power-saver"
                     : root.current === "power-saver"  ? "balanced"
                     :                                   "performance";
            setProfile.command = [ "${pkgs.power-profiles-daemon}/bin/powerprofilesctl", "set", next ];
            setProfile.running = true;
            root.current = next;
            Hyprland.dispatch("keyword misc:vfr " + (next === "performance" ? 0 : 1));
        }

        Timer { interval: 10000; running: true; triggeredOnStart: true; repeat: true; onTriggered: root.refresh() }
    }
  '';

  quickshell.modules.BarPowerToggle = ''
    import QtQuick
    import "../Services"
    import "../Common"

    Text {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        font.family: "FiraMono Nerd Font"
        font.pixelSize: 13
        color: Theme.fg
        text:  PowerProfile.current === "performance" ? "󰈸 PERF"
             : PowerProfile.current === "power-saver"  ? "󰾅 ECO"
             :                                           "󰾞 BAL"

        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onClicked:    PowerProfile.cycle()
        }
    }
  '';
}

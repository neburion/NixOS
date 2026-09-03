{ pkgs, ... }:

# PowerProfile service + toggle. Service copied verbatim from clean; the
# widget is an icon whose FILL axis tracks how aggressive the profile is.

{
  quickshell.services.PowerProfile = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
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
        Process { id: vfr;        running: false }

        function refresh() { getProfile.running = true; }

        function cycle() {
            var next = root.current === "performance" ? "power-saver"
                     : root.current === "power-saver"  ? "balanced"
                     :                                   "performance";
            setProfile.command = [ "${pkgs.power-profiles-daemon}/bin/powerprofilesctl", "set", next ];
            setProfile.running = true;
            root.current = next;

            // `keyword` is a hyprctl command, not a dispatcher, so the clean
            // preset's Hyprland.dispatch("keyword misc:vfr N") has always
            // failed with "Invalid dispatcher" — the VFR setting never moved.
            // Run it as what it is.
            vfr.command = [
                "${pkgs.hyprland}/bin/hyprctl", "keyword", "misc:vfr",
                next === "performance" ? "0" : "1"
            ];
            vfr.running = true;
        }

        Timer { interval: 10000; running: true; triggeredOnStart: true; repeat: true; onTriggered: root.refresh() }
    }
  '';

  quickshell.modules.BarPowerToggle = ''
    import QtQuick
    import "../Services"
    import "../Common"

    Text {
        id: root
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        readonly property bool perf: PowerProfile.current === "performance"
        readonly property bool eco:  PowerProfile.current === "power-saver"

        font.family: Glass.fontIcon
        font.pixelSize: 17
        font.variableAxes: root.perf ? Glass.iconActive : Glass.iconIdle
        color: root.perf ? Glass.text : Glass.muted
        // bolt / eco / balance
        text: root.perf ? "" : root.eco ? "" : ""

        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onClicked:    PowerProfile.cycle()
        }
    }
  '';
}

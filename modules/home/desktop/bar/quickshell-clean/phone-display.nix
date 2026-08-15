{ pkgs, ... }:

# PhoneDisplay service + bar indicator. Polls `pgrep wayvnc` to detect the
# phone-display headless-VNC toggle; widget is hidden when inactive.
# Click while active = stop (invokes the same toggle script as $phoneDisplay).

{
  quickshell.services.PhoneDisplay = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        property bool active: false

        Process {
            id: checkProc
            command: ["${pkgs.procps}/bin/pgrep", "-x", "wayvnc"]
            running: false
            stdout: StdioCollector { onStreamFinished: root.active = text.trim().length > 0 }
        }

        Process { id: toggleProc; running: false; onExited: root.refresh() }

        function refresh() { checkProc.running = true; }
        function toggle()  { toggleProc.command = ["phone-display-toggle"]; toggleProc.running = true; }

        Timer { interval: 2000; running: true; triggeredOnStart: true; repeat: true; onTriggered: root.refresh() }
    }
  '';

  quickshell.modules.BarPhoneDisplay = ''
    import QtQuick
    import "../Services"
    import "../Common"

    Text {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        visible: PhoneDisplay.active
        font.family: "FiraMono Nerd Font"
        font.pixelSize: 13
        color: Theme.fg
        text: "● PHONE"

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: PhoneDisplay.toggle()
        }
    }
  '';
}

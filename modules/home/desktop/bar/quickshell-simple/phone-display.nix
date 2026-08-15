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

    Rectangle {
        id: root
        visible: PhoneDisplay.active
        color: Theme.selection
        radius: 2
        implicitHeight: 28
        implicitWidth: label.implicitWidth + 10

        Text {
            id: label
            anchors.centerIn: parent
            font.family: "FiraMono Nerd Font"
            font.pixelSize: 15
            font.weight: Font.Black
            color: Theme.fg
            text: "󰺐 PHONE"
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: PhoneDisplay.toggle()
        }
    }
  '';
}

{ pkgs, ... }:

# PhoneDisplay service + bar indicator for the phone-as-display toggle.
#
# Unlike the first version of this widget, it is visible whether or not the
# session is up. A widget that only appeared once wayvnc was already running
# could stop the thing but never start it, and since nothing bound
# $phoneDisplay to a key either, there was no way in at all short of typing
# `phone-display-toggle` in a terminal. Idle is a dim `cast`; active is a
# filled `cast_connected` in the bar's accent.

{
  quickshell.services.PhoneDisplay = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        property bool active: false
        property bool busy:   false

        Process {
            id: checkProc
            command: ["${pkgs.procps}/bin/pgrep", "-x", "wayvnc"]
            running: false
            stdout: StdioCollector { onStreamFinished: root.active = text.trim().length > 0 }
        }

        // The toggle creates a monitor and waits for wayvnc to listen, so it
        // is not instant. Hold `busy` across the run to stop a second click
        // starting a race against the first.
        Process {
            id: toggleProc
            running: false
            onExited: { root.busy = false; root.refresh(); }
        }

        function refresh() { checkProc.running = true; }

        function toggle() {
            if (root.busy) return;
            root.busy = true;
            toggleProc.command = ["phone-display-toggle"];
            toggleProc.running = true;
        }

        Timer { interval: 2000; running: true; triggeredOnStart: true; repeat: true; onTriggered: root.refresh() }
    }
  '';

  quickshell.modules.BarPhoneDisplay = ''
    import QtQuick
    import "../Services"
    import "../Common"

    Text {
        id: root
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        property color accent: Glass.accentFallback

        font.family: Glass.fontIcon
        font.pixelSize: 17
        font.variableAxes: PhoneDisplay.active ? Glass.iconActive : Glass.iconIdle
        color: PhoneDisplay.active ? root.accent : Glass.muted
        opacity: PhoneDisplay.busy ? 0.45 : 1.0

        // cast / cast_connected
        text: PhoneDisplay.active ? "" : ""

        Behavior on opacity { NumberAnimation { duration: 150 } }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: PhoneDisplay.toggle()
        }
    }
  '';
}

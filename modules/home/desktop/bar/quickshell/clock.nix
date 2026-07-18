{ ... }:

# Time service + bar clock widget. Self-contained.

{
  quickshell.services.Time = ''
    pragma Singleton
    import Quickshell
    import QtQuick

    Singleton {
        id: root

        property date now: new Date()

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: root.now = new Date()
        }
    }
  '';

  quickshell.modules.BarClock = ''
    import QtQuick
    import "../Common"
    import "../Services"

    Rectangle {
        id: root
        color: Theme.surface
        radius: 5
        implicitHeight: 28
        implicitWidth: label.implicitWidth + 10

        Text {
            id: label
            anchors.centerIn: parent
            font.family: "FiraMono Nerd Font"
            font.pixelSize: 19
            font.weight: Font.Black
            color: Theme.fg
            text: Qt.formatDateTime(Time.now, "ddd dd MMM - hh:mm AP")
        }
    }
  '';
}

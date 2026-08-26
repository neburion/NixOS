{ ... }:

# Time service + clock. Tabular figures so the digits never shift width and
# the optically centred segment stays put minute to minute.

{
  quickshell.services.Time = ''
    pragma Singleton
    import Quickshell
    import QtQuick

    Singleton {
        id: root
        property date now: new Date()
        Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    }
  '';

  quickshell.modules.BarClock = ''
    import QtQuick
    import "../Services"
    import "../Common"

    Row {
        spacing: 9

        Text {
            anchors.verticalCenter: parent.verticalCenter
            font.family: Glass.fontUi
            font.pixelSize: 13
            font.weight: Font.Medium
            font.letterSpacing: -0.13
            font.features: Glass.tnum
            color: Glass.text
            text:  Qt.formatDateTime(Time.now, "HH:mm")
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            font.family: Glass.fontUi
            font.pixelSize: 12
            color: Glass.muted
            text:  Qt.formatDateTime(Time.now, "ddd dd MMM")
        }
    }
  '';
}

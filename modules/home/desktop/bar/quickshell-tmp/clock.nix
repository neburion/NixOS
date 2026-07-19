{ ... }:

# Time service + sepia clock widget. No capsule, Share Tech Mono.

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

    Text {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        font.family: "Share Tech Mono"
        font.pixelSize: 12
        color: Theme.fg
        text:  Qt.formatDateTime(Time.now, "ddd dd MMM  ·  hh:mm")
    }
  '';
}

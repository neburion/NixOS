{ ... }:

# Center date+time display — replaces scrolling ticker.

{
  quickshell.modules.BarTicker = ''
    import QtQuick
    import "../Services"
    import "../Common"

    Text {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        font.family: "Share Tech Mono"
        font.pixelSize: 12
        color: Theme.fg
        text: Qt.formatDateTime(Time.now, "ddd  dd MMM  yyyy  ·  h:mm AP")
    }
  '';
}

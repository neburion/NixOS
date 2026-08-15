{ ... }:

# Toggles the external monitor between horizontal (transform 0) and vertical
# (transform 3). Uses the shared MonitorRotation service. Sepia text, no capsule.

{
  quickshell.modules.BarMonitorToggle = ''
    import QtQuick
    import "../Services"
    import "../Common"

    Text {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        font.family: "FiraMono Nerd Font"
        font.pixelSize: 13
        color: Theme.fg
        text: MonitorRotation.transform === 0 ? "▬ HORIZ" : "▮ VERT"

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: MonitorRotation.toggle()
        }
    }
  '';
}

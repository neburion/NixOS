{ ... }:

# Toggles the external monitor between horizontal (transform 0) and vertical
# (transform 3). Uses the shared MonitorRotation service.

{
  quickshell.modules.BarMonitorToggle = ''
    import QtQuick
    import "../Common"
    import "../Services"

    Rectangle {
        id: root
        color: Theme.surface
        radius: 5
        implicitHeight: 28
        implicitWidth: label.implicitWidth + 10

        readonly property string glyph:
            MonitorRotation.transform === 0 ? "▬" : "▮"

        readonly property string labelText:
            MonitorRotation.transform === 0 ? "Horiz" : "Vert"

        Text {
            id: label
            anchors.centerIn: parent
            font.family: "FiraMono Nerd Font"
            font.pixelSize: 19
            font.weight: Font.Black
            color: Theme.fg
            text: root.glyph + " " + root.labelText
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: MonitorRotation.toggle()
        }
    }
  '';
}

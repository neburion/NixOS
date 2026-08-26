{ ... }:

# Rotates the external monitor between landscape (transform 0) and portrait
# (transform 3) via the shared MonitorRotation service. The glyph is the
# rotation state, not a label — the bar has no room for words.

{
  quickshell.modules.BarMonitorToggle = ''
    import QtQuick
    import "../Services"
    import "../Common"

    Text {
        id: root
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        readonly property bool portrait: MonitorRotation.transform !== 0

        font.family: Glass.fontIcon
        font.pixelSize: 17
        font.variableAxes: Glass.iconIdle
        color: Glass.muted
        rotation: root.portrait ? 90 : 0
        // monitor
        text: ""

        Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: MonitorRotation.toggle()
        }
    }
  '';
}

{ ... }:

# Rotates the external monitor between landscape and portrait via the shared
# MonitorRotation service, which delegates to the `rotate-monitor` script so
# the reflow happens too.
#
# The wallpaper has to be re-sent afterwards. awww holds the image at the
# geometry it was given, so a screen that has just gone portrait keeps showing
# the landscape frame stretched to fit until something pushes it again. The
# delay is for the reflow to settle first — re-sending into the old geometry
# just reproduces the stretch.

{
  quickshell.modules.BarMonitorToggle = ''
    import Quickshell
    import Quickshell.Io
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

        Process { id: refresher; running: false }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                MonitorRotation.toggle();
                refresher.command = [
                    "sh", "-c",
                    "sleep 1; glass-wallpaper-restore \"$1\"",
                    "sh", MonitorRotation.monName
                ];
                refresher.running = true;
            }
        }
    }
  '';
}

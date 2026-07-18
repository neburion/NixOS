{ ... }:

{
  quickshell.modules.OsdVolume = ''
    import Quickshell
    import Quickshell.Wayland
    import QtQuick
    import QtQuick.Layouts
    import "../Services"
    import "../Common"

    PanelWindow {
        id: root
        visible: false
        color: "transparent"
        anchors { top: true; left: true; right: true }
        implicitHeight: 70
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "osd"

        Timer {
            id: hideTimer
            interval: 2000
            onTriggered: root.visible = false
        }

        Connections {
            target: Audio
            function onVolumeChanged() { root.visible = true; hideTimer.restart(); }
            function onMutedChanged()  { root.visible = true; hideTimer.restart(); }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 10
            width: 300
            height: 50
            radius: 12
            color: Theme.surface

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                Text {
                    text: Audio.muted ? "󰝟"
                        : Audio.volume > 66 ? "󰕾"
                        : Audio.volume > 33 ? "󰖀"
                        : "󰕿"
                    color: Theme.fg
                    font.family: "FiraMono Nerd Font"
                    font.pixelSize: 18
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: Theme.bg

                    Rectangle {
                        width: parent.width * Math.min(Audio.volume / 100.0, 1.5)
                        height: parent.height
                        radius: parent.radius
                        color: Audio.muted ? Theme.selection : Theme.fg
                    }
                }

                Text {
                    text: Audio.volume + "%"
                    color: Theme.fg
                    font.family: "FiraMono Nerd Font"
                    font.pixelSize: 13
                    Layout.minimumWidth: 42
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "OsdVolume {}" ];
}

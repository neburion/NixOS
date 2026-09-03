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
        implicitHeight: 60
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "osd"

        Timer { id: hideTimer; interval: 2000; onTriggered: root.visible = false }

        Connections {
            target: Audio
            function onVolumeChanged() { root.visible = true; hideTimer.restart(); }
            function onMutedChanged()  { root.visible = true; hideTimer.restart(); }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 30
            width: 280
            height: 28
            radius: 0
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.92)
            border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3)
            border.width: 1

            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 8

                Text {
                    text: Audio.muted ? "󰝟" : Audio.volume > 66 ? "󰕾" : Audio.volume > 33 ? "󰖀" : "󰕿"
                    color: Theme.fg
                    font.family: "FiraMono Nerd Font"
                    font.pixelSize: 13
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 3
                    color: Theme.surface
                    Rectangle {
                        width: parent.width * Math.min(Audio.volume / 100.0, 1.0)
                        height: parent.height
                        color: Audio.muted ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65) : Theme.fg
                        Behavior on width { NumberAnimation { duration: 80 } }
                    }
                }

                Text {
                    text: Audio.volume + "%"
                    color: Theme.fg
                    font.family: "Share Tech Mono"
                    font.pixelSize: 11
                    Layout.minimumWidth: 36
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "OsdVolume {}" ];
}

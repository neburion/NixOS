{ ... }:

# Workspace pager. The focused workspace is marked by an accent pip rather
# than a colour change, so the digits stay one hue and the only coloured thing
# on the bar is genuinely "live".
#
# HyprlandIpc itself lives in quickshell-glass-shared — the launcher, power
# menu and picker read it too, and registering it here made them depend on the
# bar being imported.

{
  quickshell.modules.BarWorkspaces = ''
    import Quickshell.Hyprland
    import QtQuick
    import "../Services"
    import "../Common"

    Row {
        id: root
        spacing: 9

        required property string screenName
        property color accent: Glass.accentFallback

        readonly property var persistent: ({
            "eDP-1":    [ 1, 2, 3, 4, 5 ],
            "DP-1":     [ 1, 2, 3, 4, 5 ],
            "HDMI-A-1": [ 6, 7, 8, 9, 10 ]
        })

        readonly property var ids: root.persistent[root.screenName] || [ 1, 2, 3, 4, 5 ]

        Rectangle {
            width: 5; height: 5; radius: 2.5
            color: root.accent
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 220 } }
        }

        Repeater {
            model: root.ids

            delegate: Text {
                required property int modelData
                readonly property var  ws:          HyprlandIpc.workspaces.values.find(w => w.id === modelData)
                readonly property bool isOnMonitor: HyprlandIpc.monitors.values.some(m => m.activeWorkspace && m.activeWorkspace.id === modelData)
                readonly property bool isEmpty:     !ws || ws.windows === 0
                readonly property bool isOccupied:  !isEmpty && !isOnMonitor

                anchors.verticalCenter: parent.verticalCenter
                font.family: Glass.fontMono
                font.pixelSize: 11
                font.features: Glass.tnum
                color: isOnMonitor ? Glass.text
                     : isOccupied  ? Glass.muted
                     :               Glass.faint
                text: String(modelData).padStart(2, "0")

                Behavior on color { ColorAnimation { duration: 140 } }

                MouseArea {
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    HyprlandIpc.dispatch("workspace " + parent.modelData)
                }
            }
        }
    }
  '';
}

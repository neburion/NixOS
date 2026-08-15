{ ... }:

# HyprlandIpc service + workspace pager + focused client tracking.

{
  quickshell.services.HyprlandIpc = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Hyprland
    import QtQuick

    Singleton {
        id: root

        readonly property var workspaces:     Hyprland.workspaces
        readonly property var monitors:       Hyprland.monitors
        readonly property var focused:        Hyprland.focusedWorkspace
        readonly property var focusedMonitor: Hyprland.focusedMonitor
        readonly property var focusedClient:  Hyprland.focusedClient

        function dispatch(cmd) { Hyprland.dispatch(cmd); }
    }
  '';

  quickshell.modules.BarWorkspaces = ''
    import Quickshell.Hyprland
    import QtQuick
    import "../Services"
    import "../Common"

    Row {
        id: root
        spacing: 5

        required property string screenName

        readonly property var persistent: ({
            "eDP-1":    [ 1, 2, 3, 4, 5 ],
            "HDMI-A-1": [ 6, 7, 8, 9, 10 ]
        })

        readonly property var ids: root.persistent[root.screenName] || [ 1, 2, 3, 4, 5 ]

        Repeater {
            model: root.ids

            delegate: Text {
                required property int modelData
                readonly property var  ws:          HyprlandIpc.workspaces.values.find(w => w.id === modelData)
                readonly property bool isOnMonitor: HyprlandIpc.monitors.values.some(m => m.activeWorkspace && m.activeWorkspace.id === modelData)
                readonly property bool isActive:    HyprlandIpc.focused && HyprlandIpc.focused.id === modelData
                readonly property bool isEmpty:     !ws || ws.windows === 0
                readonly property bool isOccupied:  !isEmpty && !isOnMonitor

                font.family: "Share Tech Mono"
                font.pixelSize: 12
                color: isOnMonitor ? Theme.fg
                     : isOccupied  ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
                     :               Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.30)
                text: String(modelData).padStart(2, "0")

                Behavior on color { ColorAnimation { duration: 120 } }

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

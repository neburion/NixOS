{ ... }:

# Hyprland IPC service + workspace pager widget. Self-contained.

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

        function dispatch(cmd) { Hyprland.dispatch(cmd); }
    }
  '';

  quickshell.modules.BarWorkspaces = ''
    import Quickshell
    import Quickshell.Hyprland
    import QtQuick
    import QtQuick.Layouts
    import "../Common"
    import "../Services"

    Rectangle {
        id: root
        color: Theme.surface
        radius: 5
        implicitHeight: 28
        implicitWidth: layout.implicitWidth + 20

        required property string screenName

        readonly property var persistent: ({
            "eDP-1":    [ 1, 2, 3, 4, 5 ],
            "HDMI-A-1": [ 6, 7, 8, 9, 10 ]
        })

        readonly property var ids: root.persistent[root.screenName] || [ 1, 2, 3, 4, 5 ]

        RowLayout {
            id: layout
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: root.ids

                delegate: Text {
                    required property int modelData
                    readonly property var ws: HyprlandIpc.workspaces.values.find(w => w.id === modelData)
                    readonly property bool isActive: HyprlandIpc.focused && HyprlandIpc.focused.id === modelData
                    readonly property bool isEmpty: !ws || ws.windows === 0

                    font.family: "FiraMono Nerd Font"
                    font.pixelSize: 19
                    font.weight: Font.Black
                    color: Theme.fg
                    text: isActive ? "" : (isEmpty ? "" : "")

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: HyprlandIpc.dispatch("workspace " + parent.modelData)
                    }
                }
            }
        }
    }
  '';
}

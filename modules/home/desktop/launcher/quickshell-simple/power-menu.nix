{ pkgs, ... }:

# Power menu. Searchable (case-insensitive). Keyboard: type to filter, arrows
# to navigate, Enter to confirm, Esc to close.

{
  quickshell.modules.PowerMenu = ''
    import Quickshell
    import Quickshell.Io
    import Quickshell.Wayland
    import QtQuick
    import QtQuick.Controls
    import QtQuick.Layouts
    import "../Common"

    PanelWindow {
        id: root
        visible: false
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.layer: WlrLayer.Overlay

        property string query: ""

        readonly property var allActions: [
            { display: "  SHUTDOWN", cmd: "shutdown" },
            { display: "  REBOOT",   cmd: "reboot"   },
            { display: "  SUSPEND",  cmd: "suspend"  },
            { display: "  LOCK",     cmd: "lock"     },
            { display: "  LOGOUT",   cmd: "logout"   }
        ]

        readonly property var filtered: {
            var q = root.query.toLowerCase();
            if (q.length === 0) return root.allActions;
            return root.allActions.filter(function(a) {
                return a.display.toLowerCase().indexOf(q) !== -1;
            });
        }

        onQueryChanged: list.currentIndex = 0

        Process {
            id: runner
            running: false
        }

        function run(cmd) {
            var argv;
            switch (cmd) {
                case "shutdown": argv = ["sh", "-c", "hypr-session-save; ${pkgs.systemd}/bin/systemctl poweroff"]; break;
                case "reboot":   argv = ["sh", "-c", "hypr-session-save; ${pkgs.systemd}/bin/systemctl reboot"];   break;
                case "suspend":  argv = ["${pkgs.systemd}/bin/systemctl", "suspend"]; break;
                case "lock":     argv = ["${pkgs.hyprlock}/bin/hyprlock"]; break;
                case "logout":   argv = ["sh", "-c", "hypr-session-save; ${pkgs.hyprland}/bin/hyprctl dispatch exit"]; break;
            }
            runner.command = argv;
            runner.running = true;
            root.visible = false;
        }

        IpcHandler {
            target: "powerMenu"
            function toggle() {
                root.visible = !root.visible;
                if (root.visible) { root.query = ""; input.text = ""; input.forceActiveFocus(); }
            }
            function show() { root.visible = true;  root.query = ""; input.text = ""; input.forceActiveFocus(); }
            function hide() { root.visible = false; }
        }

        MouseArea { anchors.fill: parent; onClicked: root.visible = false }

        Rectangle {
            anchors.centerIn: parent
            width: 260
            height: 308
            radius: 10
            color: Theme.bg
            border.color: Theme.surface
            border.width: 1
            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                TextField {
                    id: input
                    Layout.fillWidth: true
                    placeholderText: ">"
                    color: Theme.fg
                    font.family: "FiraMono Nerd Font"
                    font.pixelSize: 14
                    background: Rectangle { color: Theme.surface; radius: 20 }
                    onTextChanged: root.query = text
                    Keys.onEscapePressed: root.visible = false
                    Keys.onReturnPressed: {
                        if (list.count > 0) {
                            var action = root.filtered[list.currentIndex];
                            if (action) root.run(action.cmd);
                        }
                    }
                    Keys.onDownPressed: list.incrementCurrentIndex()
                    Keys.onUpPressed:   list.decrementCurrentIndex()
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.filtered
                    currentIndex: 0

                    Keys.onEscapePressed: root.visible = false
                    Keys.onReturnPressed: {
                        if (count > 0) {
                            var action = root.filtered[currentIndex];
                            if (action) root.run(action.cmd);
                        }
                    }

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: list.width
                        height: 40
                        radius: 8
                        color: index === list.currentIndex ? Theme.selection : "transparent"

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            text: row.modelData.display
                            color: Theme.fg
                            font.family: "FiraMono Nerd Font"
                            font.pixelSize: 14
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.run(row.modelData.cmd)
                        }
                    }
                }
            }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "PowerMenu {}" ];
}

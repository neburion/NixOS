{ pkgs, ... }:

# Power menu — terminal aesthetic matching AppLauncher, Theme-reactive colors.

{
  quickshell.modules.PowerMenu = ''
    import Quickshell
    import Quickshell.Io
    import Quickshell.Wayland
    import QtQuick
    import QtQuick.Layouts
    import "../Common"

    PanelWindow {
        id: root
        visible: false
        anchors { top: true; left: true; right: true; bottom: true }
        color: "#cc000000"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.layer: WlrLayer.Overlay

        property string query: ""
        onVisibleChanged: if (!visible) { root.query = ""; input.text = ""; }

        readonly property var allActions: [
            { icon: "", label: "SHUTDOWN", cmd: "shutdown" },
            { icon: "", label: "REBOOT",   cmd: "reboot"   },
            { icon: "", label: "SUSPEND",  cmd: "suspend"  },
            { icon: "󰌾", label: "LOCK",     cmd: "lock"     },
            { icon: "󰍃", label: "LOGOUT",   cmd: "logout"   }
        ]

        readonly property var filtered: {
            var q = root.query.toLowerCase();
            if (q.length === 0) return root.allActions;
            return root.allActions.filter(function(a) {
                return a.label.toLowerCase().indexOf(q) !== -1;
            });
        }

        onQueryChanged: list.currentIndex = 0

        Process { id: runner; running: false }

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
            function toggle() { root.visible = !root.visible; if (root.visible) input.forceActiveFocus(); }
            function show()   { root.visible = true;  input.forceActiveFocus(); }
            function hide()   { root.visible = false; }
        }

        MouseArea { anchors.fill: parent; onClicked: root.visible = false }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.35, 360)
            height: mainCol.implicitHeight
            color: Theme.bg
            border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3)
            border.width: 1
            radius: 0
            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: mainCol
                anchors { left: parent.left; right: parent.right; top: parent.top }
                spacing: 0

                // Header
                Rectangle {
                    Layout.fillWidth: true
                    height: 28
                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.04)
                    Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12) }
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text { text: "SYSTEM CONTROL"; font.family: "Share Tech Mono"; font.pixelSize: 11; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.55); font.letterSpacing: 2 }
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: root.filtered.length + " ENTRIES"
                        font.family: "Share Tech Mono"; font.pixelSize: 11; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.38); font.letterSpacing: 1
                    }
                }

                // Search
                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    color: "transparent"
                    Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08) }
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 6
                        Text { text: ">_"; font.family: "Share Tech Mono"; font.pixelSize: 12; color: Theme.fg }
                        TextInput {
                            id: input
                            width: 260
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: "Share Tech Mono"; font.pixelSize: 12
                            color: Theme.fg
                            selectionColor: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3)
                            onTextChanged: root.query = text
                            Keys.onEscapePressed: root.visible = false
                            Keys.onReturnPressed: { if (list.count > 0) { var a = root.filtered[list.currentIndex]; if (a) root.run(a.cmd); } }
                            Keys.onDownPressed: list.incrementCurrentIndex()
                            Keys.onUpPressed:   list.decrementCurrentIndex()
                        }
                    }
                }

                // Action list
                ListView {
                    id: list
                    Layout.fillWidth: true
                    implicitHeight: count * 36
                    model: root.filtered
                    currentIndex: 0
                    clip: true

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: list.width
                        height: 36
                        color: index === list.currentIndex ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.07) : "transparent"

                        Rectangle {
                            visible: index === list.currentIndex
                            anchors.left: parent.left
                            width: 2; height: parent.height
                            color: Theme.fg
                        }

                        Row {
                            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                            spacing: 10
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: "FiraMono Nerd Font"; font.pixelSize: 14
                                color: index === list.currentIndex ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.55)
                                text: row.modelData.icon
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: "Share Tech Mono"; font.pixelSize: 12
                                color: index === list.currentIndex ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.55)
                                text: row.modelData.label
                            }
                        }

                        MouseArea { anchors.fill: parent; onClicked: root.run(row.modelData.cmd) }
                    }
                }

                // Footer
                Rectangle {
                    Layout.fillWidth: true
                    height: 22
                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.04)
                    Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08) }
                    Text {
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: "↑↓ NAVIGATE  ·  ENTER CONFIRM  ·  ESC CLOSE"
                        font.family: "Share Tech Mono"; font.pixelSize: 10; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3); font.letterSpacing: 1
                    }
                }
            }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "PowerMenu {}" ];
}

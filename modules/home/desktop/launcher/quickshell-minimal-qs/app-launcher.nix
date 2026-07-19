{ ... }:

# drun-style application launcher. Toggled via `qs ipc call launcher toggle`.
# Reads .desktop entries from XDG dirs (Quickshell.DesktopEntries service).

{
  quickshell.modules.AppLauncher = ''
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

        // Only the launcher card grabs focus + keyboard; the rest of the
        // fullscreen layer window is a click-through dismiss target.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.layer: WlrLayer.Overlay

        property string query: ""

        // Clear the query on every close so reopening starts fresh, no matter
        // which dismiss path fired (Escape, toggle, click-outside, execute).
        onVisibleChanged: if (!visible) { root.query = ""; input.text = ""; }

        readonly property var filtered: {
            var q = root.query.toLowerCase();
            var all = DesktopEntries.applications.values;
            if (q.length === 0) return all.slice(0, 50);
            return all.filter(function(a) {
                return a.name.toLowerCase().indexOf(q) !== -1
                    || (a.genericName && a.genericName.toLowerCase().indexOf(q) !== -1);
            }).slice(0, 50);
        }

        IpcHandler {
            target: "launcher"
            function toggle() { root.visible = !root.visible; if (root.visible) input.forceActiveFocus(); }
            function show()   { root.visible = true;  input.forceActiveFocus(); }
            function hide()   { root.visible = false; root.query = ""; }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.visible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.35
            height: parent.height * 0.4
            radius: 10
            color: Theme.bg
            border.color: Theme.surface
            border.width: 1

            MouseArea { anchors.fill: parent; onClicked: {} }  // eat clicks

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
                            var app = root.filtered[list.currentIndex];
                            if (app) { app.execute(); root.visible = false; root.query = ""; }
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

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: list.width
                        height: 32
                        radius: 20
                        color: index === list.currentIndex ? Theme.selection : "transparent"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            spacing: 8

                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                source: modelData.icon
                                    ? (modelData.icon.startsWith("/") ? "file://" + modelData.icon : "image://icon/" + modelData.icon)
                                    : ""
                                sourceSize.width: 20
                                sourceSize.height: 20
                                visible: modelData.icon && modelData.icon.length > 0
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: Theme.fg
                                font.family: "FiraMono Nerd Font"
                                font.pixelSize: 14
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                modelData.execute();
                                root.visible = false;
                                root.query = "";
                            }
                        }
                    }
                }
            }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "AppLauncher {}" ];
  quickshell.shellExtraImports    = [ "import QtQuick.Controls" ];
}

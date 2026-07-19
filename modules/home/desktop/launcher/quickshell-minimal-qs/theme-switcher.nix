{ ... }:

# Theme picker. Searchable (case-insensitive). Color swatches per theme.
# Keyboard: type to filter, arrows to navigate, Enter to apply, Esc to close.

{
  quickshell.modules.ThemeSwitcher = ''
    import Quickshell
    import Quickshell.Io
    import Quickshell.Wayland
    import QtQuick
    import QtQuick.Controls
    import QtQuick.Layouts
    import "../Common"
    import "../Services"

    PanelWindow {
        id: root
        visible: false
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.layer: WlrLayer.Overlay

        property string query: ""

        readonly property var filtered: {
            var q = root.query.toLowerCase();
            if (q.length === 0) return Theme.names;
            return Theme.names.filter(function(n) {
                return n.toLowerCase().indexOf(q) !== -1;
            });
        }

        onQueryChanged: list.currentIndex = 0

        IpcHandler {
            target: "themeSwitcher"
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
            width: 300
            height: 330
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
                            ThemeState.setActive(root.filtered[list.currentIndex]);
                            root.visible = false;
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
                            ThemeState.setActive(root.filtered[currentIndex]);
                            root.visible = false;
                        }
                    }

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: list.width
                        height: 44
                        radius: 8
                        color: index === list.currentIndex ? Theme.selection : "transparent"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            spacing: 10

                            // Color swatch: bg / surface / selection strips
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 36
                                height: 22
                                radius: 4
                                clip: true

                                Row {
                                    Rectangle {
                                        width: 12; height: 22
                                        color: Theme.palettes[row.modelData]
                                               ? Theme.palettes[row.modelData].bg
                                               : Theme.bg
                                    }
                                    Rectangle {
                                        width: 12; height: 22
                                        color: Theme.palettes[row.modelData]
                                               ? Theme.palettes[row.modelData].surface
                                               : Theme.surface
                                    }
                                    Rectangle {
                                        width: 12; height: 22
                                        color: Theme.palettes[row.modelData]
                                               ? Theme.palettes[row.modelData].selection
                                               : Theme.selection
                                    }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.toUpperCase()
                                color: Theme.fg
                                font.family: "FiraMono Nerd Font"
                                font.pixelSize: 13
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.modelData === Theme.activeName
                            text: "✓"
                            color: Theme.fg
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                ThemeState.setActive(row.modelData);
                                root.visible = false;
                            }
                        }
                    }
                }
            }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "ThemeSwitcher {}" ];
}

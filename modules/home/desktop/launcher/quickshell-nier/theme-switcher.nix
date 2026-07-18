{ ... }:

# Theme switcher — terminal aesthetic matching AppLauncher, Theme-reactive colors.

{
  quickshell.modules.ThemeSwitcher = ''
    import Quickshell
    import Quickshell.Io
    import Quickshell.Wayland
    import QtQuick
    import QtQuick.Layouts
    import "../Common"
    import "../Services"

    PanelWindow {
        id: root
        visible: false
        anchors { top: true; left: true; right: true; bottom: true }
        color: "#cc000000"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.layer: WlrLayer.Overlay

        property string query: ""
        onVisibleChanged: if (!visible) { root.query = ""; input.text = ""; }

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
            function toggle() { root.visible = !root.visible; if (root.visible) input.forceActiveFocus(); }
            function show()   { root.visible = true;  input.forceActiveFocus(); }
            function hide()   { root.visible = false; }
        }

        MouseArea { anchors.fill: parent; onClicked: root.visible = false }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.35, 380)
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
                    Text {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        text: "THEME SELECT"; font.family: "Share Tech Mono"; font.pixelSize: 11; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.55); font.letterSpacing: 2
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
                            width: 280
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: "Share Tech Mono"; font.pixelSize: 12
                            color: Theme.fg
                            selectionColor: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3)
                            onTextChanged: root.query = text
                            Keys.onEscapePressed: root.visible = false
                            Keys.onReturnPressed: { if (list.count > 0) { ThemeState.setActive(root.filtered[list.currentIndex]); root.visible = false; } }
                            Keys.onDownPressed: list.incrementCurrentIndex()
                            Keys.onUpPressed:   list.decrementCurrentIndex()
                        }
                    }
                }

                // Column headers
                Rectangle {
                    Layout.fillWidth: true
                    height: 22
                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.04)
                    Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.06) }
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 0
                        Text { text: "PALETTE"; font.family: "Share Tech Mono"; font.pixelSize: 10; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3); font.letterSpacing: 2; width: 60 }
                        Text { text: "NAME"; font.family: "Share Tech Mono"; font.pixelSize: 10; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3); font.letterSpacing: 2 }
                    }
                }

                // Theme list
                ListView {
                    id: list
                    Layout.fillWidth: true
                    implicitHeight: Math.min(count * 32, 240)
                    model: root.filtered
                    currentIndex: 0
                    clip: true

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: list.width
                        height: 32
                        color: index === list.currentIndex ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.07) : "transparent"

                        Rectangle {
                            visible: index === list.currentIndex
                            anchors.left: parent.left
                            width: 2; height: parent.height
                            color: Theme.fg
                        }

                        Row {
                            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                            spacing: 0

                            // Color swatch
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 60
                                spacing: 0
                                Repeater {
                                    model: ["bg", "surface", "selection", "fg"]
                                    Rectangle {
                                        width: 12; height: 18
                                        color: Theme.palettes[row.modelData]
                                               ? Theme.palettes[row.modelData][modelData]
                                               : "transparent"
                                    }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: "Share Tech Mono"; font.pixelSize: 12
                                color: index === list.currentIndex ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
                                text: row.modelData.toUpperCase()
                            }
                        }

                        Text {
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            visible: row.modelData === Theme.activeName
                            text: "ACTIVE"
                            font.family: "Share Tech Mono"; font.pixelSize: 10
                            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.4)
                            font.letterSpacing: 1
                        }

                        MouseArea { anchors.fill: parent; onClicked: { ThemeState.setActive(row.modelData); root.visible = false; } }
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
                        text: "↑↓ NAVIGATE  ·  ENTER APPLY  ·  ESC CLOSE"
                        font.family: "Share Tech Mono"; font.pixelSize: 10; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3); font.letterSpacing: 1
                    }
                }
            }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "ThemeSwitcher {}" ];
}

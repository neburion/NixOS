{ ... }:

# NieR app launcher — terminal aesthetic, Theme-reactive colors.

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
        color: "#cc000000"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.layer: WlrLayer.Overlay

        property string query: ""
        onVisibleChanged: if (!visible) { root.query = ""; input.text = ""; }

        readonly property var filtered: {
            var q = root.query.toLowerCase();
            var all = DesktopEntries.applications.values;
            if (q.length === 0) return all.slice(0, 60);
            return all.filter(function(a) {
                return a.name.toLowerCase().indexOf(q) !== -1
                    || (a.genericName && a.genericName.toLowerCase().indexOf(q) !== -1)
                    || (a.categories && a.categories.toString().toLowerCase().indexOf(q) !== -1);
            }).slice(0, 60);
        }

        IpcHandler {
            target: "launcher"
            function toggle() { root.visible = !root.visible; if (root.visible) input.forceActiveFocus(); }
            function show()   { root.visible = true;  input.forceActiveFocus(); }
            function hide()   { root.visible = false; root.query = ""; }
        }

        MouseArea { anchors.fill: parent; onClicked: root.visible = false }

        Rectangle {
            anchors.centerIn: parent
            width:  Math.min(parent.width * 0.5, 720)
            height: Math.min(parent.height * 0.65, 520)
            color:  Theme.bg
            border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3)
            border.width: 1
            radius: 0

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 0
                spacing: 0

                // Header bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 28
                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.04)
                    Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12) }

                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text { text: "APPLICATION SELECT"; font.family: "Share Tech Mono"; font.pixelSize: 11; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.55); font.letterSpacing: 2 }
                    }

                    Text {
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: root.filtered.length + " ENTRIES"
                        font.family: "Share Tech Mono"; font.pixelSize: 11; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.38); font.letterSpacing: 1
                    }
                }

                // Search input
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
                            width: 600
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: "Share Tech Mono"
                            font.pixelSize: 12
                            color: Theme.fg
                            selectionColor: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3)
                            onTextChanged: root.query = text
                            Keys.onEscapePressed: root.visible = false
                            Keys.onReturnPressed: {
                                if (list.count > 0) {
                                    var app = root.filtered[list.currentIndex];
                                    if (app) { app.execute(); root.visible = false; }
                                }
                            }
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
                        Text { text: "NAME"; font.family: "Share Tech Mono"; font.pixelSize: 10; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3); font.letterSpacing: 2; width: 260 }
                        Text { text: "CATEGORY"; font.family: "Share Tech Mono"; font.pixelSize: 10; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3); font.letterSpacing: 2 }
                    }
                }

                // App list
                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.filtered
                    currentIndex: 0
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: list.width
                        height: 28
                        color: index === list.currentIndex ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.07) : "transparent"

                        Rectangle {
                            visible: index === list.currentIndex
                            anchors.left: parent.left
                            width: 2; height: parent.height
                            color: Theme.fg
                        }

                        Row {
                            anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 0

                            Text {
                                width: 260
                                text: modelData.name
                                color: index === list.currentIndex ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
                                font.family: "Share Tech Mono"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width - 260
                                text: modelData.categories ? modelData.categories[0] || "" : ""
                                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3)
                                font.family: "Share Tech Mono"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: { modelData.execute(); root.visible = false; root.query = ""; }
                        }
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
                        text: "↑↓ NAVIGATE  ·  ENTER LAUNCH  ·  ESC CLOSE"
                        font.family: "Share Tech Mono"; font.pixelSize: 10; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3); font.letterSpacing: 1
                    }
                }
            }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "AppLauncher {}" ];
  quickshell.shellExtraImports    = [ "import QtQuick.Controls" ];
}

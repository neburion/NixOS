{ ... }:

# Tray container. Chip on bar always visible; click opens ONE popup that
# contains tray icons at the top and (when an icon is right-clicked) a
# sepia-themed DBusMenu below. Single popup + single focus grab = no
# race / hand-off bugs, so right-click no longer sends a stray click into
# the underlying app.

{
  quickshell.modules.BarTray = ''
    import Quickshell
    import Quickshell.Io
    import Quickshell.Services.SystemTray
    import QtQuick
    import QtQuick.Layouts
    import "../Common"
    import "../Services"

    Item {
        id: root
        implicitHeight: parent ? parent.height : 28
        implicitWidth: chipRow.implicitWidth

        // Which tray item's menu is expanded, or null.
        property var activeMenuItem: null

        QsMenuOpener {
            id: menuOpener
            menu: root.activeMenuItem ? root.activeMenuItem.menu : null
        }

        Row {
            id: chipRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: "FiraMono Nerd Font"
                font.pixelSize: 13
                color: Theme.fg
                text: "󰀻 TRAY"
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                var opening = PopupState.owner !== root;
                PopupState.toggle(root);
                if (opening) root.activeMenuItem = null;
            }
        }

        PopupWindow {
            id: containerPopup
            visible: PopupState.owner === root
            grabFocus: true
            onClosed: {
                if (PopupState.owner === root) PopupState.close();
                root.activeMenuItem = null;
            }
            color: "transparent"
            implicitWidth: containerBg.implicitWidth
            implicitHeight: containerBg.implicitHeight

            anchor.item: root
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom
            anchor.margins.top: 6

            Rectangle {
                id: containerBg
                color: Theme.bg
                border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3)
                border.width: 1
                radius: 4
                implicitWidth: Math.max(
                    iconsRow.implicitWidth + 20,
                    root.activeMenuItem !== null ? 240 : 60
                )
                implicitHeight: contentCol.implicitHeight + 12

                Column {
                    id: contentCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                    spacing: 6

                    // Icons row.
                    Item {
                        width: parent.width
                        height: 28

                        RowLayout {
                            id: iconsRow
                            anchors.centerIn: parent
                            spacing: 12
                            visible: SystemTray.items.values.length > 0

                            Repeater {
                                model: SystemTray.items

                                delegate: MouseArea {
                                    id: trayCell
                                    required property SystemTrayItem modelData
                                    implicitHeight: 20
                                    implicitWidth: 20
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 24; height: 24; radius: 3
                                        color: Theme.surface
                                        visible: root.activeMenuItem === trayCell.modelData
                                    }

                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.MiddleButton) {
                                            modelData.secondaryActivate();
                                            PopupState.close();
                                        } else if (mouse.button === Qt.RightButton) {
                                            // Toggle inline menu for this icon.
                                            // No focus hand-off; container stays open.
                                            root.activeMenuItem =
                                                root.activeMenuItem === modelData ? null : modelData;
                                        } else {
                                            modelData.activate();
                                            if (modelData.id && modelData.id.length > 0) {
                                                launchProc.command = ["tray-launch", modelData.id];
                                                launchProc.running = true;
                                            }
                                            PopupState.close();
                                        }
                                    }

                                    Process { id: launchProc; running: false; }

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.icon
                                        smooth: true
                                        mipmap: true
                                        sourceSize.width: 20
                                        sourceSize.height: 20
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: SystemTray.items.values.length === 0
                            font.family: "Share Tech Mono"
                            font.pixelSize: 11
                            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.55)
                            text: "EMPTY"
                        }
                    }

                    // Separator + menu, only when active.
                    Rectangle {
                        visible: root.activeMenuItem !== null
                        width: parent.width
                        height: 1
                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.25)
                    }

                    Column {
                        visible: root.activeMenuItem !== null
                        width: parent.width
                        spacing: 0

                        Repeater {
                            model: menuOpener.children
                            delegate: Item {
                                required property QsMenuEntry modelData
                                width: parent.width
                                implicitHeight: modelData.isSeparator ? 7 : 26

                                Rectangle {
                                    visible: modelData.isSeparator
                                    anchors {
                                        left: parent.left; right: parent.right
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: 6; rightMargin: 6
                                    }
                                    height: 1
                                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.25)
                                }

                                Rectangle {
                                    visible: !modelData.isSeparator
                                    anchors.fill: parent
                                    radius: 2
                                    color: rowMouse.containsMouse && modelData.enabled
                                        ? Theme.surface : "transparent"

                                    Row {
                                        anchors {
                                            left: parent.left; right: parent.right
                                            verticalCenter: parent.verticalCenter
                                            leftMargin: 8; rightMargin: 8
                                        }
                                        spacing: 6

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            font.family: "FiraMono Nerd Font"
                                            font.pixelSize: 11
                                            color: modelData.checkState === Qt.Checked
                                                ? Theme.fg
                                                : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.75)
                                            visible: modelData.buttonType !== QsMenuButtonType.None
                                            text: {
                                                if (modelData.buttonType === QsMenuButtonType.CheckBox)
                                                    return modelData.checkState === Qt.Checked ? "󰄲" : "󰄱";
                                                if (modelData.buttonType === QsMenuButtonType.RadioButton)
                                                    return modelData.checkState === Qt.Checked ? "󰐾" : "󰄰";
                                                return "";
                                            }
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            font.family: "Share Tech Mono"
                                            font.pixelSize: 12
                                            color: modelData.enabled
                                                ? Theme.fg
                                                : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.4)
                                            text: modelData.text.replace(/&/g, "")
                                            width: parent.width - (submenuArrow.visible ? 20 : 0)
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        id: submenuArrow
                                        visible: modelData.hasChildren
                                        anchors {
                                            right: parent.right; verticalCenter: parent.verticalCenter
                                            rightMargin: 8
                                        }
                                        font.family: "FiraMono Nerd Font"
                                        font.pixelSize: 10
                                        color: Theme.fg
                                        text: "󰅂"
                                    }

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        enabled: modelData.enabled
                                        onClicked: {
                                            if (!modelData.hasChildren) {
                                                modelData.triggered();
                                                PopupState.close();
                                                root.activeMenuItem = null;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            visible: menuOpener.children.length === 0
                            width: parent.width
                            height: 26
                            Text {
                                anchors.centerIn: parent
                                font.family: "Share Tech Mono"
                                font.pixelSize: 11
                                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.55)
                                text: "NO ACTIONS"
                            }
                        }
                    }
                }
            }
        }
    }
  '';
}

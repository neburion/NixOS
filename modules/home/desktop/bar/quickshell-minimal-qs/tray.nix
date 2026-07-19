{ ... }:

# System tray. Right-click opens a themed QML popup rendered from the tray
# item's DBusMenu (via QsMenuOpener). Left click sends SNI Activate and, as
# a fallback for Ayatana apps that don't implement it (Spotify), focuses the
# matching Hyprland window by class. Middle click sends SecondaryActivate.

{
  quickshell.modules.BarTray = ''
    import Quickshell
    import Quickshell.Io
    import Quickshell.Services.SystemTray
    import QtQuick
    import QtQuick.Layouts
    import "../Common"
    import "../Services"

    Rectangle {
        id: root
        color: Theme.surface
        radius: 5
        implicitHeight: 28
        implicitWidth: layout.implicitWidth + 14
        visible: SystemTray.items.values.length > 0

        RowLayout {
            id: layout
            anchors.centerIn: parent
            spacing: 10

            Repeater {
                model: SystemTray.items

                delegate: MouseArea {
                    id: trayCell
                    required property SystemTrayItem modelData
                    implicitHeight: 16
                    implicitWidth: 16
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton) {
                            PopupState.toggle(trayCell);
                        } else {
                            // Standard: send SNI Activate. Ayatana apps often
                            // don't implement it — tray-launch focuses the
                            // window by class or launches by command name.
                            modelData.activate();
                            if (modelData.id && modelData.id.length > 0) {
                                launchProc.command = ["tray-launch", modelData.id];
                                launchProc.running = true;
                            }
                        }
                    }

                    Process { id: launchProc; running: false; }

                    Image {
                        anchors.fill: parent
                        source: modelData.icon
                        smooth: true
                        mipmap: true
                        sourceSize.width: 16
                        sourceSize.height: 16
                    }

                    QsMenuOpener {
                        id: menuOpener
                        menu: trayCell.modelData.menu
                    }

                    PopupWindow {
                        id: menuPopup
                        visible: PopupState.owner === trayCell
                        grabFocus: true
                        color: "transparent"
                        implicitWidth: 220
                        implicitHeight: menuBg.implicitHeight

                        onClosed: if (PopupState.owner === trayCell) PopupState.close()

                        anchor.item: trayCell
                        anchor.edges: Edges.Bottom
                        anchor.gravity: Edges.Bottom
                        anchor.margins.top: 6

                        Rectangle {
                            id: menuBg
                            anchors.fill: parent
                            color: Theme.bg
                            border.color: Theme.surface
                            border.width: 1
                            radius: 8
                            implicitHeight: menuCol.implicitHeight + 8

                            Column {
                                id: menuCol
                                anchors {
                                    left: parent.left; right: parent.right
                                    top: parent.top; margins: 4
                                }
                                spacing: 0

                                Repeater {
                                    model: menuOpener.children
                                    delegate: Item {
                                        required property QsMenuEntry modelData
                                        width: menuCol.width
                                        implicitHeight: modelData.isSeparator ? 7 : 26

                                        Rectangle {
                                            visible: modelData.isSeparator
                                            anchors {
                                                left: parent.left; right: parent.right
                                                verticalCenter: parent.verticalCenter
                                                leftMargin: 6; rightMargin: 6
                                            }
                                            height: 1
                                            color: Theme.surface
                                        }

                                        Rectangle {
                                            visible: !modelData.isSeparator
                                            anchors.fill: parent
                                            radius: 4
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
                                                    font.pixelSize: 12
                                                    color: modelData.checkState === Qt.Checked ? Theme.selection : Theme.fg
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
                                                    font.family: "FiraMono Nerd Font"
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
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
  '';
}

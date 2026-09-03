{ ... }:

# Tray container. Icon on the bar always visible; click opens ONE popup that
# holds the tray icons at the top and, when an icon is right-clicked, its
# DBusMenu below. Single popup + single focus grab = no race or hand-off bug,
# so right-click never sends a stray click into the underlying app.
#
# Structure is the clean tray's; only the presentation is glass.

{
  quickshell.modules.BarTray = ''
    import Quickshell
    import Quickshell.Io
    import Quickshell.Services.SystemTray
    import QtQuick
    import QtQuick.Layouts
    import "../Common"
    import "../Services"
    import "../Widgets"

    Item {
        id: root
        implicitHeight: 20
        implicitWidth:  chip.implicitWidth

        // Which tray item's menu is expanded, or null.
        property var activeMenuItem: null

        QsMenuOpener {
            id: menuOpener
            menu: root.activeMenuItem ? root.activeMenuItem.menu : null
        }

        Text {
            id: chip
            anchors.centerIn: parent
            font.family: Glass.fontIcon
            font.pixelSize: 17
            font.variableAxes: PopupState.owner === root ? Glass.iconActive : Glass.iconIdle
            color: PopupState.owner === root ? Glass.text : Glass.muted
            text: ""
            Behavior on color { ColorAnimation { duration: 160 } }
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
            implicitWidth:  shell.implicitWidth
            implicitHeight: shell.implicitHeight

            anchor.item: root
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom
            anchor.margins.top: 10

            GlassSurface {
                id: shell
                strong: true
                implicitWidth: Math.max(
                    iconsRow.implicitWidth + 20,
                    root.activeMenuItem !== null ? 240 : 56
                )
                implicitHeight: contentCol.implicitHeight + 16

                Column {
                    id: contentCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                    spacing: 6

                    // ---- icons ----
                    //
                    // Left-aligned on the same 10px inset as the menu rows
                    // below. Centring them meant they drifted to the middle of
                    // a container that jumps to 240px wide as soon as a menu
                    // opens, leaving a wide gap either side of two icons.
                    Item {
                        width: parent.width
                        height: 30

                        RowLayout {
                            id: iconsRow
                            anchors {
                                left: parent.left
                                leftMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 10
                            visible: SystemTray.items.values.length > 0

                            Repeater {
                                model: SystemTray.items

                                delegate: MouseArea {
                                    id: trayCell
                                    required property SystemTrayItem modelData
                                    implicitHeight: 22
                                    implicitWidth:  22
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 28; height: 28; radius: 9
                                        color: Glass.hover
                                        visible: root.activeMenuItem === trayCell.modelData
                                    }

                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.MiddleButton) {
                                            modelData.secondaryActivate();
                                            PopupState.close();
                                        } else if (mouse.button === Qt.RightButton) {
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
                                        sourceSize.width:  22
                                        sourceSize.height: 22
                                    }
                                }
                            }
                        }

                        Text {
                            anchors {
                                left: parent.left
                                leftMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            visible: SystemTray.items.values.length === 0
                            font.family: Glass.fontUi
                            font.pixelSize: 12
                            color: Glass.faint
                            text: "Nothing in the tray"
                        }
                    }

                    Rectangle {
                        visible: root.activeMenuItem !== null
                        width: parent.width
                        height: 1
                        color: Glass.stroke
                    }

                    // ---- that icon's menu ----
                    Column {
                        visible: root.activeMenuItem !== null
                        width: parent.width
                        spacing: 0

                        Repeater {
                            model: menuOpener.children
                            delegate: Item {
                                required property QsMenuEntry modelData
                                width: parent.width
                                implicitHeight: modelData.isSeparator ? 9 : 30

                                Rectangle {
                                    visible: modelData.isSeparator
                                    anchors {
                                        left: parent.left; right: parent.right
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: 8; rightMargin: 8
                                    }
                                    height: 1
                                    color: Glass.stroke
                                }

                                Rectangle {
                                    visible: !modelData.isSeparator
                                    anchors.fill: parent
                                    radius: Glass.rowRadius
                                    color: rowMouse.containsMouse && modelData.enabled
                                        ? Glass.hover : "transparent"
                                    Behavior on color { ColorAnimation { duration: 110 } }

                                    Row {
                                        anchors {
                                            left: parent.left; right: parent.right
                                            verticalCenter: parent.verticalCenter
                                            leftMargin: 10; rightMargin: 10
                                        }
                                        spacing: 8

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            font.family: Glass.fontIcon
                                            font.pixelSize: 15
                                            font.variableAxes: modelData.checkState === Qt.Checked
                                                ? Glass.iconActive : Glass.iconIdle
                                            color: modelData.checkState === Qt.Checked ? Glass.text : Glass.muted
                                            visible: modelData.buttonType !== QsMenuButtonType.None
                                            text: {
                                                if (modelData.buttonType === QsMenuButtonType.CheckBox)
                                                    return modelData.checkState === Qt.Checked ? "" : "";
                                                if (modelData.buttonType === QsMenuButtonType.RadioButton)
                                                    return modelData.checkState === Qt.Checked ? "" : "";
                                                return "";
                                            }
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            font.family: Glass.fontUi
                                            font.pixelSize: 13
                                            font.letterSpacing: -0.1
                                            color: modelData.enabled ? Glass.text : Glass.faint
                                            text: modelData.text.replace(/&/g, "")
                                            width: parent.width - (submenuArrow.visible ? 22 : 0)
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        id: submenuArrow
                                        visible: modelData.hasChildren
                                        anchors {
                                            right: parent.right; verticalCenter: parent.verticalCenter
                                            rightMargin: 10
                                        }
                                        font.family: Glass.fontIcon
                                        font.pixelSize: 15
                                        font.variableAxes: Glass.iconIdle
                                        color: Glass.muted
                                        text: ""
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
                            height: 30
                            Text {
                                anchors.centerIn: parent
                                font.family: Glass.fontUi
                                font.pixelSize: 12
                                color: Glass.faint
                                text: "No actions"
                            }
                        }
                    }
                }
            }
        }
    }
  '';
}

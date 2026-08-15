{ ... }:

# fdo.Notifications sink + layer window stack in the top-right, matching the
# current mako placement. Replaces modules/home/desktop/notifications/mako/.

{
  quickshell.modules.NotificationCenter = ''
    import Quickshell
    import Quickshell.Services.Notifications
    import Quickshell.Wayland
    import QtQuick
    import "../Common"

    Item {
        id: root

        NotificationServer {
            id: server
            keepOnReload: true
            actionsSupported: true
            bodySupported: true
            bodyMarkupSupported: true
            imageSupported: true
        }

        Variants {
            model: Quickshell.screens

            delegate: PanelWindow {
                id: window
                required property ShellScreen modelData
                screen: modelData

                anchors { top: true; right: true }
                margins.top: 48
                margins.right: 10

                color: "transparent"
                implicitWidth: 320
                implicitHeight: Math.max(1, stack.implicitHeight)

                Column {
                    id: stack
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: ScriptModel {
                            values: server.trackedNotifications.values.slice(-5)
                        }

                        delegate: Rectangle {
                            required property Notification modelData
                            width: parent.width
                            radius: 12
                            color: Theme.bg
                            border.color: Theme.surface
                            border.width: 1
                            implicitHeight: content.implicitHeight + 24

                            Timer {
                                interval: modelData.expireTimeout > 0
                                    ? modelData.expireTimeout
                                    : 5000
                                running: true
                                repeat: false
                                onTriggered: modelData.dismiss()
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: modelData.dismiss()
                            }

                            Column {
                                id: content
                                anchors.centerIn: parent
                                width: parent.width - 30
                                spacing: 4

                                Text {
                                    width: parent.width
                                    font.family: "FiraMono Nerd Font"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: Theme.fg
                                    wrapMode: Text.Wrap
                                    text: modelData.appName + ": " + modelData.summary
                                }
                                Text {
                                    visible: modelData.body && modelData.body.length > 0
                                    width: parent.width
                                    font.family: "FiraMono Nerd Font"
                                    font.pixelSize: 11
                                    color: Theme.fg
                                    wrapMode: Text.Wrap
                                    textFormat: Text.MarkdownText
                                    text: modelData.body
                                }
                                Row {
                                    visible: modelData.actions.values.length > 0
                                    spacing: 6
                                    topPadding: 4

                                    Repeater {
                                        model: ScriptModel {
                                            values: modelData.actions.values
                                        }

                                        delegate: Rectangle {
                                            required property NotificationAction modelData
                                            color: Theme.surface
                                            radius: 4
                                            implicitHeight: actionText.implicitHeight + 8
                                            implicitWidth: actionText.implicitWidth + 16

                                            Text {
                                                id: actionText
                                                anchors.centerIn: parent
                                                font.family: "FiraMono Nerd Font"
                                                font.pixelSize: 11
                                                color: Theme.fg
                                                text: modelData.text
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    modelData.invoke()
                                                    modelData.notification.dismiss()
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

  quickshell.moduleInstantiations = [ "NotificationCenter {}" ];
}

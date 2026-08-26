{ ... }:

# fdo.Notifications sink + a stack of glass cards under the bar, top right.
# Overlay layer with no exclusive zone, so these DO sit over windows — unlike
# the bar, which reserves space. That is the point of a notification.

{
  quickshell.modules.NotificationCenter = ''
    import Quickshell
    import Quickshell.Services.Notifications
    import Quickshell.Wayland
    import QtQuick
    import "../Services"
    import "../Common"
    import "../Widgets"

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
                margins.top: Glass.barZone + 8
                margins.right: Glass.barMargin

                color: "transparent"
                implicitWidth: 320
                implicitHeight: Math.max(1, stack.implicitHeight)

                WlrLayershell.namespace: "quickshell:notifications"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                readonly property color accent: WallpaperState.accentFor(modelData.name)

                Column {
                    id: stack
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: ScriptModel {
                            values: server.trackedNotifications.values.slice(-5)
                        }

                        delegate: GlassSurface {
                            required property Notification modelData

                            width: parent.width
                            radius: 15
                            implicitHeight: content.implicitHeight + 26

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
                                anchors {
                                    left: parent.left; right: parent.right
                                    top: parent.top
                                    leftMargin: 14; rightMargin: 14; topMargin: 13
                                }
                                spacing: 3

                                Text {
                                    width: parent.width
                                    font.family: Glass.fontMono
                                    font.pixelSize: 10
                                    font.letterSpacing: 1.2
                                    color: Glass.faint
                                    elide: Text.ElideRight
                                    text: modelData.appName.toUpperCase()
                                }

                                Text {
                                    width: parent.width
                                    font.family: Glass.fontUi
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: -0.13
                                    color: Glass.text
                                    wrapMode: Text.Wrap
                                    text: modelData.summary
                                }

                                Text {
                                    visible: modelData.body && modelData.body.length > 0
                                    width: parent.width
                                    font.family: Glass.fontUi
                                    font.pixelSize: 12
                                    color: Glass.muted
                                    wrapMode: Text.Wrap
                                    textFormat: Text.MarkdownText
                                    text: modelData.body
                                }

                                Row {
                                    visible: modelData.actions.values.length > 0
                                    spacing: 6
                                    topPadding: 7

                                    Repeater {
                                        model: ScriptModel {
                                            values: modelData.actions.values
                                        }

                                        delegate: Rectangle {
                                            required property NotificationAction modelData

                                            color: actionMouse.containsMouse
                                                 ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                                            radius: 9
                                            implicitHeight: actionText.implicitHeight + 12
                                            implicitWidth:  actionText.implicitWidth + 22
                                            Behavior on color { ColorAnimation { duration: 110 } }

                                            Text {
                                                id: actionText
                                                anchors.centerIn: parent
                                                font.family: Glass.fontUi
                                                font.pixelSize: 12
                                                color: Glass.text
                                                text: modelData.text
                                            }

                                            MouseArea {
                                                id: actionMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
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

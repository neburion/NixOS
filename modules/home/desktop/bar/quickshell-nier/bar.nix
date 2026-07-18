{ ... }:

# NieR bar — 28px sepia bar with bottom border accent.
# Layout mirrors unit3 waybar: workspaces+title | katakana ticker | stats+clock.

{
  quickshell.modules.Bar = ''
    import Quickshell
    import Quickshell.Wayland
    import QtQuick
    import "../Common"

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: window
            required property ShellScreen modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            implicitHeight: 28
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.92)

            // Bottom accent line
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left:   parent.left
                anchors.right:  parent.right
                height: 1
                color:  Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3)
            }

            // Left: workspaces + active window title
            Row {
                anchors.left:           parent.left
                anchors.leftMargin:     12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                BarWorkspaces { screenName: window.modelData.name }

                Rectangle {
                    width: 1; height: 14; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3)
                    anchors.verticalCenter: parent.verticalCenter
                }

                BarWindowTitle { }
            }

            // Center: katakana ticker
            BarTicker { anchors.centerIn: parent }

            // Right: hardware | wifi | bluetooth | clock | power
            Row {
                anchors.right:          parent.right
                anchors.rightMargin:    12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                BarHardwareGroup { }

                Rectangle { width: 1; height: 14; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3); anchors.verticalCenter: parent.verticalCenter }

                BarWifi { }
                BarBluetooth { }

                Rectangle { width: 1; height: 14; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3); anchors.verticalCenter: parent.verticalCenter }

                BarPowerToggle { }
            }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "Bar {}" ];
}

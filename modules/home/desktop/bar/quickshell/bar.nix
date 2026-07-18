{ ... }:

# Top-level bar container. One PanelWindow per screen, anchored top-full-width.

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
            implicitHeight: 38
            color: Theme.bg

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                BarClock { }
                BarPowerToggle { }
            }

            BarWorkspaces {
                anchors.centerIn: parent
                screenName: window.modelData.name
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                BarTray { }
                BarWifi { }
                BarBluetooth { }
                BarHardwareGroup { }
            }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "Bar {}" ];
}

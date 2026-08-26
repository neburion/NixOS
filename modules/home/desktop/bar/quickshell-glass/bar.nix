{ ... }:

# One inset glass panel per screen. 50px exclusive zone across the full width
# so windows tile underneath and nothing ever overlaps; the visible 34px panel
# floats inside that strip with margins on all four sides.
#
# Layout: workspaces + quick toggles | clock (optically centred) | stats + radios.
# The centre segment is anchored to the panel rather than laid out between the
# other two, so a growing tray never nudges the clock off centre.

{
  quickshell.modules.Bar = ''
    import Quickshell
    import Quickshell.Wayland
    import QtQuick
    import "../Services"
    import "../Common"
    import "../Widgets"

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: window
            required property ShellScreen modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            implicitHeight: Glass.barZone
            color: "transparent"

            WlrLayershell.namespace: "quickshell:bar"
            WlrLayershell.layer: WlrLayer.Top

            // Per-monitor: this screen's wallpaper decides this bar's accent.
            readonly property color accent: WallpaperState.accentFor(modelData.name)

            GlassSurface {
                id: panel

                anchors {
                    left:       parent.left
                    right:      parent.right
                    top:        parent.top
                    leftMargin:  Glass.barMargin
                    rightMargin: Glass.barMargin
                    topMargin:   Glass.barTop
                }
                height: Glass.barHeight
                radius: Glass.barRadius

                // ---- left ----
                Row {
                    anchors {
                        left: parent.left
                        leftMargin: 16
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 13

                    BarWorkspaces {
                        screenName: window.modelData.name
                        accent:     window.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 1; height: 13
                        color: Qt.rgba(1, 1, 1, 0.13)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    BarTray { }
                    BarPowerToggle { }
                    BarMonitorToggle { }
                }

                // ---- centre ----
                BarClock { anchors.centerIn: parent }

                // ---- right ----
                Row {
                    anchors {
                        right: parent.right
                        rightMargin: 16
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 13

                    BarHardwareGroup { accent: window.accent }

                    Rectangle {
                        width: 1; height: 13
                        color: Qt.rgba(1, 1, 1, 0.13)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    BarWifi { }
                    BarBluetooth { }
                }
            }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "Bar {}" ];
}

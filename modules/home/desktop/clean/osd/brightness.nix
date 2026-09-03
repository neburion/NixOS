{ hostConfig, ... }:

# BrightnessState service + brightness OSD widget. Self-contained.
# Sysfs paths baked at build time from hostConfig.backlight.

let
  bp  = hostConfig.backlight.sysfsBrightnessPath;
  mbp = hostConfig.backlight.sysfsMaxBrightnessPath;
in

{
  quickshell.services.BrightnessState = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        property int brightness:    0
        property int maxBrightness: 100
        property int percent: maxBrightness > 0
            ? Math.round(brightness / maxBrightness * 100)
            : 0

        FileView {
            path: "${bp}"
            watchChanges: true
            onFileChanged: reload()
            onLoaded: {
                var v = parseInt(text().trim());
                if (!isNaN(v)) root.brightness = v;
            }
        }

        FileView {
            path: "${mbp}"
            onLoaded: {
                var v = parseInt(text().trim());
                if (!isNaN(v)) root.maxBrightness = v;
            }
        }
    }
  '';

  quickshell.modules.OsdBrightness = ''
    import Quickshell
    import Quickshell.Wayland
    import QtQuick
    import QtQuick.Layouts
    import "../Services"
    import "../Common"

    PanelWindow {
        id: root
        visible: false
        color: "transparent"
        anchors { top: true; left: true; right: true }
        implicitHeight: 60
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "osd"

        Timer { id: hideTimer; interval: 2000; onTriggered: root.visible = false }

        Connections {
            target: BrightnessState
            function onPercentChanged() { root.visible = true; hideTimer.restart(); }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 30
            width: 280
            height: 28
            radius: 0
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.92)
            border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3)
            border.width: 1

            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 8

                Text {
                    text: BrightnessState.percent > 66 ? "󰃠" : BrightnessState.percent > 33 ? "󰃟" : "󰃞"
                    color: Theme.fg
                    font.family: "FiraMono Nerd Font"
                    font.pixelSize: 13
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 3
                    color: Theme.surface
                    Rectangle {
                        width: parent.width * (BrightnessState.percent / 100.0)
                        height: parent.height
                        color: Theme.fg
                        Behavior on width { NumberAnimation { duration: 80 } }
                    }
                }

                Text {
                    text: BrightnessState.percent + "%"
                    color: Theme.fg
                    font.family: "Share Tech Mono"
                    font.pixelSize: 11
                    Layout.minimumWidth: 36
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "OsdBrightness {}" ];
}

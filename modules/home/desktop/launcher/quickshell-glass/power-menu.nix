{ pkgs, ... }:

# Power menu. Five actions, no search field — with a fixed list this short a
# text input is a step between you and the button, and arrow keys plus the
# first letter already get you there.
#
# The dispatch table is the clean menu's verbatim, including hypr-session-save
# before anything that ends the session.

{
  quickshell.modules.PowerMenu = ''
    import Quickshell
    import Quickshell.Io
    import Quickshell.Wayland
    import QtQuick
    import "../Services"
    import "../Common"
    import "../Widgets"

    PanelWindow {
        id: root
        visible: false
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"

        WlrLayershell.namespace: "quickshell:launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.layer: WlrLayer.Overlay
        // Without this the overlay still honours the bar's 50px exclusive
        // zone and the scrim stops short of the top of the screen.
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        readonly property color accent:
            WallpaperState.accentFor(HyprlandIpc.focusedMonitor
                                     ? HyprlandIpc.focusedMonitor.name : "")

        readonly property var actions: [
            { glyph: "",   label: "Shut down", key: "s", cmd: "shutdown" },
            { glyph: "", label: "Restart",   key: "r", cmd: "reboot"   },
            { glyph: "",   label: "Suspend",   key: "u", cmd: "suspend"  },
            { glyph: "",    label: "Lock",      key: "l", cmd: "lock"     },
            { glyph: "",  label: "Log out",   key: "o", cmd: "logout"   }
        ]

        property int index: 0
        onVisibleChanged: if (visible) { root.index = 0; keys.forceActiveFocus(); }

        Process { id: runner; running: false }

        function run(cmd) {
            var argv;
            switch (cmd) {
                case "shutdown": argv = ["sh", "-c", "hypr-session-save; ${pkgs.systemd}/bin/systemctl poweroff"]; break;
                case "reboot":   argv = ["sh", "-c", "hypr-session-save; ${pkgs.systemd}/bin/systemctl reboot"];   break;
                case "suspend":  argv = ["${pkgs.systemd}/bin/systemctl", "suspend"]; break;
                case "lock":     argv = ["${pkgs.hyprlock}/bin/hyprlock"]; break;
                case "logout":   argv = ["sh", "-c", "hypr-session-save; ${pkgs.hyprland}/bin/hyprctl dispatch exit"]; break;
            }
            runner.command = argv;
            runner.running = true;
            root.visible = false;
        }

        IpcHandler {
            target: "powerMenu"
            function toggle() { root.visible = !root.visible; }
            function show()   { root.visible = true;  }
            function hide()   { root.visible = false; }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Glass.ink.r, Glass.ink.g, Glass.ink.b, 0.55)
            MouseArea { anchors.fill: parent; onClicked: root.visible = false }
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: root.visible

            Keys.onEscapePressed: root.visible = false
            Keys.onReturnPressed: root.run(root.actions[root.index].cmd)
            Keys.onDownPressed:   root.index = (root.index + 1) % root.actions.length
            Keys.onUpPressed:     root.index = (root.index + root.actions.length - 1) % root.actions.length
            Keys.onPressed: (event) => {
                const t = event.text.toLowerCase();
                for (let i = 0; i < root.actions.length; i++) {
                    if (root.actions[i].key === t) {
                        root.index = i;
                        root.run(root.actions[i].cmd);
                        event.accepted = true;
                        return;
                    }
                }
            }

            GlassSurface {
                anchors.centerIn: parent
                width:  Math.min(parent.width - 48, 300)
                height: col.implicitHeight + 12
                radius: Glass.launcherRadius

                MouseArea { anchors.fill: parent; onClicked: {} }

                Column {
                    id: col
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                    spacing: 2

                    Repeater {
                        model: root.actions

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width:  col.width
                            height: Glass.rowHeight + 2
                            radius: Glass.rowRadius
                            color: index === root.index ? Glass.hover : "transparent"
                            Behavior on color { ColorAnimation { duration: 110 } }

                            Row {
                                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                                spacing: 13

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.family: Glass.fontIcon
                                    font.pixelSize: 18
                                    font.variableAxes: index === root.index ? Glass.iconActive : Glass.iconIdle
                                    color: index === root.index ? root.accent : Glass.muted
                                    text:  modelData.glyph
                                    Behavior on color { ColorAnimation { duration: 140 } }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.family: Glass.fontUi
                                    font.pixelSize: 14
                                    font.letterSpacing: -0.11
                                    color: index === root.index ? Glass.text : Glass.muted
                                    text:  modelData.label
                                }
                            }

                            Text {
                                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                                font.family: Glass.fontMono
                                font.pixelSize: 11
                                color: Glass.faint
                                text:  modelData.key.toUpperCase()
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onEntered:    root.index = index
                                onClicked:    root.run(modelData.cmd)
                            }
                        }
                    }
                }
            }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "PowerMenu {}" ];
}

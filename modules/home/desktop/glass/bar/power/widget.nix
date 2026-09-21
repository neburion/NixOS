{ config, lib, ... }:

# Modules/BarPower.qml — the dial in the bar and the menu behind it.
#
# This file names no battery. It reads whatever sources/ registered, in
# `order`, and everything below works the same whether that list is one entry
# or five: the dial grows, the menu's columns divide, and the number beside
# the dial is the lowest of whatever answered.
#
# It replaced three separate widgets — the laptop battery, the peripherals
# readout and the power toggle. They were three because they arrived
# separately, not because they are three things; all of them answer "how is
# this machine doing for power", and the profile is the only one of them you
# can act on, which is what the menu is for.

let
  ordered =
    lib.sort (a: b: a.order < b.order)
      (lib.mapAttrsToList (name: src: src // { inherit name; })
        config.quickshell.powerSources);

  # Each reading is indented into an array literal, tagged so a QML error
  # names the source rather than a line number in a generated file.
  readings = lib.concatMapStringsSep ",\n" (s:
    "            /* ${s.name} */ ${lib.replaceStrings [ "\n" ] [ "\n            " ] (lib.removeSuffix "\n" s.reading)}"
  ) ordered;

  refreshes = lib.concatMapStringsSep "\n" (s: "                ${s.refresh}")
    (lib.filter (s: s.refresh != "") ordered);
in
{
  quickshell.modules.BarPower = ''
    import Quickshell
    import QtQuick
    import "../Services"
    import "../Common"
    import "../Widgets"

    Item {
        id: root

        implicitWidth:  line.implicitWidth
        implicitHeight: line.implicitHeight

        property color accent: Glass.accentFallback

        // Contributed by modules/home/desktop/glass/bar/power/sources/.
        readonly property var readings: [
${readings}
        ]

        // Defaults filled here rather than in every source: a source that
        // does not care about colour gets the wallpaper's, and one that does
        // not burn says nothing at all.
        readonly property var sources: {
            var out = [];
            for (var i = 0; i < root.readings.length; i++) {
                var s = root.readings[i];
                out.push({
                    label:   s.label,
                    present: s.present === true,
                    value:   s.present === true ? s.value : 0,
                    caption: s.caption !== undefined ? s.caption : "",
                    color:   s.color   !== undefined ? s.color : root.accent,
                    burning: s.burning === true
                });
            }
            return out;
        }

        // Only what answered gets a ring, so the dial is as wide as the
        // number of things currently on this machine.
        readonly property var live: {
            var out = [];
            for (var i = 0; i < root.sources.length; i++)
                if (root.sources[i].present) out.push(root.sources[i]);
            return out;
        }

        readonly property bool burning: {
            for (var i = 0; i < root.live.length; i++)
                if (root.live[i].burning) return true;
            return false;
        }

        readonly property int worst: {
            var lowest = 101;
            for (var i = 0; i < root.live.length; i++)
                if (root.live[i].value < lowest) lowest = root.live[i].value;
            return lowest === 101 ? 0 : lowest;
        }

        readonly property bool alert: worst > 0 && worst <= 20

        function refreshAll() {
${refreshes}
            PowerProfile.refresh();
        }

        Row {
            id: line
            anchors.centerIn: parent
            spacing: 5

            Item {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth:  gauge.implicitWidth
                implicitHeight: gauge.implicitHeight

                // Behind the rings and wider than them, so the tongues flank
                // the gauge instead of hiding behind it, and rising through
                // the gap at the bottom. 32 is the whole panel less a hair —
                // the fire is the tallest thing the bar draws, and it has
                // nowhere else to go.
                Flame {
                    anchors {
                        bottom: parent.bottom; bottomMargin: -2
                        horizontalCenter: parent.horizontalCenter
                    }
                    width:   gauge.implicitWidth * 1.30
                    height:  32
                    tongues: 4
                    valley:  0.07
                    shoulder: 0.72
                    burning: root.burning
                }

                Dial {
                    id: gauge
                    anchors.centerIn: parent
                    rings: root.live
                    knockout: root.burning
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Glass.fontUi
                font.pixelSize: 12
                font.features: Glass.tnum
                // The rings carry proportion and the profile; this carries
                // the one number worth knowing, and it is the only thing here
                // that goes red for a flat cell — the outer ring's colour is
                // already spoken for.
                color: root.alert ? Glass.critical : Glass.muted
                text:  root.worst + "%"
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onClicked: {
                var opening = PopupState.owner !== root;
                PopupState.toggle(root);
                if (opening) root.refreshAll();
            }
        }

        PopupWindow {
            id: popup
            visible: PopupState.owner === root
            grabFocus: true
            onClosed: if (PopupState.owner === root) PopupState.close()
            color: "transparent"
            implicitWidth: Math.max(240, 96 * root.sources.length + 20)
            implicitHeight: shell.implicitHeight

            anchor.item: root
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom
            anchor.margins.top: 10

            GlassSurface {
                id: shell
                anchors.fill: parent
                strong: true
                implicitHeight: col.implicitHeight + 20

                Column {
                    id: col
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                    spacing: 8

                    Text {
                        height: 30
                        verticalAlignment: Text.AlignVCenter
                        font.family: Glass.fontUi
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.letterSpacing: -0.13
                        color: Glass.text
                        text:  "Power"
                    }

                    // Every source, present or not — a headset that is off is
                    // worth saying out loud here, even though it earns no ring
                    // in the bar.
                    Row {
                        id: dials
                        width: parent.width
                        bottomPadding: 4

                        Repeater {
                            model: root.sources

                            delegate: Column {
                                required property var modelData
                                width: dials.width / root.sources.length
                                spacing: 6

                                // Every cell grows, not just the one that is
                                // alight, or the labels under them stop
                                // lining up across the row.
                                Item {
                                    width: 56
                                    height: root.burning ? 78 : 52
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    Behavior on height {
                                        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                                    }

                                    Flame {
                                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                                        width:  56
                                        height: 74
                                        tongues: 5
                                        valley:  0.06
                                        shoulder: 0.74
                                        burning: modelData.burning
                                    }
                                    Flame {
                                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                                        width:  26
                                        height: 38
                                        tongues: 2
                                        shoulder: 0.82
                                        inner:   true
                                        burning: modelData.burning
                                    }

                                    Dial {
                                        id: cell
                                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                                        outer: 46
                                        thickness: 2.8
                                        rings: [ modelData ]
                                        knockout: modelData.burning
                                    }

                                    Text {
                                        anchors.centerIn: cell
                                        font.family: Glass.fontUi
                                        font.pixelSize: 12
                                        font.features: Glass.tnum
                                        color: modelData.present ? Glass.text : Glass.faint
                                        text:  modelData.present ? modelData.value + "%" : "—"
                                    }
                                }

                                Text {
                                    width: parent.width - 6
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: Glass.fontUi
                                    font.pixelSize: 11
                                    color: modelData.present ? Glass.text : Glass.muted
                                    text:  modelData.label
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width - 6
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: Glass.fontUi
                                    font.pixelSize: 10
                                    color: Glass.faint
                                    text:  modelData.caption
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // The toggle this replaced cycled power-saver ->
                    // balanced -> performance on click, so reaching
                    // performance from balanced took two clicks and a guess
                    // at where you were. Three cells, one click, and the
                    // selected one wears the colour the outer ring is wearing.
                    Rectangle {
                        width:  parent.width
                        height: 32
                        radius: 11
                        color:  Qt.rgba(1, 1, 1, 0.05)

                        Row {
                            id: cells
                            anchors.fill: parent
                            anchors.margins: 3
                            spacing: 3

                            Repeater {
                                model: PowerProfile.profiles

                                delegate: Rectangle {
                                    required property var modelData

                                    readonly property bool on: PowerProfile.current === modelData.id

                                    width:  (cells.width - 6) / 3
                                    height: cells.height
                                    radius: 8
                                    color: on ? Qt.rgba(PowerProfile.tint.r, PowerProfile.tint.g,
                                                        PowerProfile.tint.b, 0.24)
                                         : hover.containsMouse ? Glass.hover
                                         :                       "transparent"

                                    Behavior on color { ColorAnimation { duration: 140 } }

                                    Text {
                                        anchors.centerIn: parent
                                        font.family: Glass.fontUi
                                        font.pixelSize: 11
                                        color: parent.on ? Glass.text : Glass.muted
                                        text:  modelData.label
                                    }

                                    MouseArea {
                                        id: hover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape:  Qt.PointingHandCursor
                                        onClicked:    PowerProfile.set(modelData.id)
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

{ ... }:

# One dial for every cell in reach, and the menu behind it.
#
# This replaces three widgets: the laptop battery, the peripherals readout and
# the power toggle. They were three because they arrived separately, not
# because they are three things — all of them answer "how is this machine
# doing for power", and the toggle is the only one of the three you can act
# on, which is exactly what a menu is for.
#
# The bar carries the dial and one number, the lowest of whatever is present.
# Rings, outermost in: laptop, mouse, headset. The order is fixed and the
# tracks are drawn whether or not a device answers, so the ring a reading sits
# on never moves under you.
#
# The outer ring is the odd one out — it is tinted by the power profile rather
# than the wallpaper, so the machine's mode is legible from the bar without
# spending a second glyph on it. Green idling, amber working, red and
# flickering while it burns.

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

        readonly property var mouse:   Peripherals.mouse
        readonly property var headset: Peripherals.headset

        // Outermost first. Absence is a value the dial understands, so the
        // list is always three long and the rings never renumber themselves.
        readonly property var sources: [
            {
                value:   Battery.capacity,
                present: Battery.present,
                color:   PowerProfile.tint,
                burning: PowerProfile.burning,
                label:   "Laptop",
                caption: Battery.charging ? "Charging" : "Discharging"
            },
            {
                value:   root.mouse ? root.mouse.percent : 0,
                present: !!root.mouse,
                color:   root.accent,
                burning: false,
                label:   root.mouse ? root.mouse.label : "Mouse",
                caption: root.mouse ? root.mouse.caption : "Not connected"
            },
            {
                value:   root.headset ? root.headset.percent : 0,
                present: !!root.headset,
                color:   root.accent,
                burning: false,
                label:   root.headset ? root.headset.label : "Headset",
                caption: root.headset ? root.headset.caption : "Off"
            }
        ]

        readonly property int worst: {
            var lowest = 101;
            for (var i = 0; i < root.sources.length; i++) {
                var s = root.sources[i];
                if (s.present && s.value < lowest) lowest = s.value;
            }
            return lowest === 101 ? 0 : lowest;
        }

        readonly property bool alert: worst > 0 && worst <= 20

        Row {
            id: line
            anchors.centerIn: parent
            spacing: 5

            Dial {
                anchors.verticalCenter: parent.verticalCenter
                size: 26
                thickness: 1.9
                spacing: 1.3
                rings: root.sources
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Glass.fontUi
                font.pixelSize: 12
                font.features: Glass.tnum
                // The rings carry proportion and the profile; this carries the
                // one number worth knowing, and it is the only thing here that
                // goes red for a flat battery — the outer ring's colour is
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
                if (opening) { Peripherals.refresh(); PowerProfile.refresh(); }
            }
        }

        PopupWindow {
            id: popup
            visible: PopupState.owner === root
            grabFocus: true
            onClosed: if (PopupState.owner === root) PopupState.close()
            color: "transparent"
            implicitWidth: 300
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

                    Row {
                        id: dials
                        width: parent.width
                        bottomPadding: 4

                        Repeater {
                            model: root.sources

                            delegate: Column {
                                required property var modelData
                                width: dials.width / 3
                                spacing: 6

                                Item {
                                    width: 46; height: 46
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Dial {
                                        anchors.centerIn: parent
                                        size: 46
                                        thickness: 2.6
                                        rings: [ modelData ]
                                    }

                                    Text {
                                        anchors.centerIn: parent
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

                    // The toggle used to cycle power-saver -> balanced ->
                    // performance on click, which meant reaching performance
                    // from balanced took two clicks and a guess at where you
                    // were. Three cells, one click, and the selected one wears
                    // the same colour the outer ring is wearing.
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
                                    color: on    ? Qt.rgba(PowerProfile.tint.r, PowerProfile.tint.g,
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

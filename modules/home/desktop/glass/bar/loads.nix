{ ... }:

# The three load meters and the menu behind them.
#
# Five dashes each in the bar, and everything the bar cannot say in a popup:
# what the GPU actually is and how hot, what the CPU is and what it is
# carrying, how much memory is gone in gigabytes rather than percent. The
# numbers left the bar when these became meters; this is where they went.
#
# The three sit tighter to each other than to their neighbours. They are one
# subject and one click target, and the bar's 13px rhythm between unrelated
# widgets would say otherwise.

{
  # Five dashes, lit from the left. Quantised on purpose: the bar cannot
  # honestly resolve more than five steps at this size, and a meter that
  # claims otherwise is a number wearing a costume. The numbers themselves are
  # gone from these three — they were never the reason you glance at them.
  #
  # Thresholds sit at 10/30/50/70/90 rather than 20/40/60/80/100, so a pip
  # lights at the value it is nearest to. Below 10 the row is empty, which is
  # not a fault — this dGPU really does sit at 0% whenever nothing is drawing,
  # and five dark dashes is what that should look like.
  quickshell.widgets.BarMeter = ''
    import QtQuick
    import "../Common"

    Item {
        id: root

        property string glyph:     ""
        // Material Symbols unless something says otherwise.
        property string glyphFont: Glass.fontIcon
        property real   glyphSize: 15
        property int    value:     0
        property int    alertAt: 101
        property color  tint:    Glass.muted

        readonly property bool alert: value >= alertAt

        implicitWidth:  line.implicitWidth
        implicitHeight: line.implicitHeight

        Row {
            id: line
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: root.glyphFont
                font.pixelSize: root.glyphSize
                font.variableAxes: Glass.iconIdle
                color: root.alert ? Glass.critical : Glass.muted
                text:  root.glyph
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: 5
                    delegate: Rectangle {
                        required property int index

                        readonly property bool lit: root.value >= index * 20 + 10

                        width: 3; height: 13; radius: 1.5
                        color: !lit       ? Qt.rgba(1, 1, 1, 0.11)
                             : root.alert ? Glass.critical
                             :              root.tint
                        Behavior on color { ColorAnimation { duration: 220 } }
                    }
                }
            }
        }
    }
  '';

  # A popup row for one load: glyph, name, percentage, a line or two of
  # detail, and a bar. Lives here rather than in popup-widgets.nix because
  # this is the only menu built out of readings.
  quickshell.widgets.PopupGauge = ''
    import QtQuick
    import "../Common"

    Item {
        id: root

        property string glyph:     ""
        property string glyphFont: Glass.fontIcon
        property real   glyphSize: 16
        property string title:     ""
        property int    value:     0
        property int    alertAt:   101
        property var    detail:    []
        property color  tint:      Glass.muted

        readonly property bool alert: value >= alertAt

        implicitHeight: 24 + lines.implicitHeight + 9

        Text {
            id: mark
            anchors { left: parent.left; leftMargin: 10; top: parent.top; topMargin: 2 }
            font.family: root.glyphFont
            font.pixelSize: root.glyphSize
            font.variableAxes: Glass.iconIdle
            color: root.alert ? Glass.critical : Glass.muted
            text:  root.glyph
        }

        Text {
            id: pct
            anchors { right: parent.right; rightMargin: 10; top: parent.top; topMargin: 2 }
            font.family: Glass.fontUi
            font.pixelSize: 13
            font.features: Glass.tnum
            color: root.alert ? Glass.critical : Glass.text
            text:  root.value + "%"
        }

        Text {
            id: name
            anchors {
                left:  mark.right; leftMargin: 10
                right: pct.left;   rightMargin: 8
                baseline: pct.baseline
            }
            font.family: Glass.fontUi
            font.pixelSize: 13
            font.letterSpacing: -0.1
            color: Glass.text
            text:  root.title
            elide: Text.ElideRight
        }

        Column {
            id: lines
            anchors { left: name.left; right: parent.right; rightMargin: 10; top: name.bottom; topMargin: 1 }
            spacing: 0

            Repeater {
                model: root.detail
                delegate: Text {
                    required property var modelData
                    width: lines.width
                    font.family: Glass.fontUi
                    font.pixelSize: 11
                    color: Glass.faint
                    text:  modelData
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            anchors {
                left: name.left; right: parent.right; rightMargin: 10
                bottom: parent.bottom; bottomMargin: 5
            }
            height: 3
            radius: 1.5
            color: Qt.rgba(1, 1, 1, 0.09)

            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width:  parent.width * Math.max(0, Math.min(100, root.value)) / 100
                radius: 1.5
                color:  root.alert ? Glass.critical : root.tint
                Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            }
        }
    }
  '';

  quickshell.modules.BarLoads = ''
    import Quickshell
    import QtQuick
    import "../Services"
    import "../Common"
    import "../Widgets"

    Item {
        id: root

        property color accent: Glass.accentFallback

        implicitWidth:  line.implicitWidth
        implicitHeight: line.implicitHeight

        function gib(v) { return v.toFixed(1); }

        Row {
            id: line
            anchors.centerIn: parent
            // Tighter than the 13 between unrelated widgets: these three are
            // one subject and one click target.
            spacing: 8

            BarMeter {
                anchors.verticalCenter: parent.verticalCenter
                glyph:     String.fromCodePoint(0xF08AE)
                glyphFont: Glass.fontGlyph
                glyphSize: 14
                value:     SystemStats.gpuPercent
                alertAt:   95
                tint:      root.accent
            }

            BarMeter {
                anchors.verticalCenter: parent.verticalCenter
                glyph:   "\ue322"
                value:   SystemStats.cpuPercent
                alertAt: 90
                tint:    root.accent
            }

            BarMeter {
                anchors.verticalCenter: parent.verticalCenter
                glyph:   "\uf7a3"
                value:   SystemStats.memPercent
                alertAt: 85
                tint:    root.accent
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onClicked:    PopupState.toggle(root)
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
                    spacing: 4

                    Text {
                        height: 30
                        verticalAlignment: Text.AlignVCenter
                        font.family: Glass.fontUi
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.letterSpacing: -0.13
                        color: Glass.text
                        text:  "Hardware"
                    }

                    PopupGauge {
                        width: parent.width
                        glyph:     String.fromCodePoint(0xF08AE)
                        glyphFont: Glass.fontGlyph
                        glyphSize: 15
                        title:   "Graphics"
                        value:   SystemStats.gpuPercent
                        alertAt: 95
                        tint:    root.accent
                        detail: [
                            SystemStats.gpuName,
                            root.gib(SystemStats.gpuMemUsed / 1024) + " / "
                              + root.gib(SystemStats.gpuMemTotal / 1024) + " GiB   ·   "
                              + SystemStats.gpuTemp + " °C   ·   "
                              + SystemStats.gpuClock + " MHz"
                        ]
                    }

                    PopupGauge {
                        width: parent.width
                        glyph:   "\ue322"
                        title:   "Processor"
                        value:   SystemStats.cpuPercent
                        alertAt: 90
                        tint:    root.accent
                        detail: [
                            SystemStats.cpuModel,
                            "load  " + SystemStats.loadAvg
                              + (SystemStats.cpuTemp > 0
                                 ? "   ·   " + SystemStats.cpuTemp + " °C" : "")
                        ]
                    }

                    PopupGauge {
                        width: parent.width
                        glyph:   "\uf7a3"
                        title:   "Memory"
                        value:   SystemStats.memPercent
                        alertAt: 85
                        tint:    root.accent
                        detail: [
                            root.gib(SystemStats.memUsedGiB) + " / "
                              + root.gib(SystemStats.memTotalGiB) + " GiB in use",
                            SystemStats.swapTotalGiB > 0
                              ? "swap  " + root.gib(SystemStats.swapUsedGiB) + " / "
                                + root.gib(SystemStats.swapTotalGiB) + " GiB"
                              : "no swap"
                        ]
                    }
                }
            }
        }
    }
  '';
}

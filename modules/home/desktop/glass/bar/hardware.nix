{ pkgs, ... }:

# SystemStats service + the right-hand stats cluster. Service copied verbatim
# from clean; only the presentation changed — icon plus tabular percentage,
# and thresholds recolour to critical rather than to a warning hue.

{
  quickshell.services.SystemStats = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        property int cpuPercent: 0
        property int memPercent: 0
        property int gpuPercent: 0

        property real lastTotal: 0
        property real lastIdle:  0

        FileView {
            id: statFile
            path: "/proc/stat"
            watchChanges: false
            onLoaded: {
                var line = text().split("\n")[0];
                var f = line.trim().split(/\s+/);
                var user    = parseFloat(f[1]);
                var nice    = parseFloat(f[2]);
                var sys     = parseFloat(f[3]);
                var idle    = parseFloat(f[4]);
                var iowait  = parseFloat(f[5] || 0);
                var irq     = parseFloat(f[6] || 0);
                var softirq = parseFloat(f[7] || 0);
                var total   = user + nice + sys + idle + iowait + irq + softirq;
                var idleAll = idle + iowait;
                if (root.lastTotal > 0) {
                    var dt = total - root.lastTotal;
                    var di = idleAll - root.lastIdle;
                    if (dt > 0) root.cpuPercent = Math.round((1 - di / dt) * 100);
                }
                root.lastTotal = total;
                root.lastIdle  = idleAll;
            }
        }

        FileView {
            id: memFile
            path: "/proc/meminfo"
            watchChanges: false
            onLoaded: {
                var t = text();
                var mTotal = /MemTotal:\s+(\d+)/.exec(t);
                var mAvail = /MemAvailable:\s+(\d+)/.exec(t);
                if (mTotal && mAvail) {
                    var total = parseInt(mTotal[1], 10);
                    var avail = parseInt(mAvail[1], 10);
                    root.memPercent = Math.round((1 - avail / total) * 100);
                }
            }
        }

        Process {
            id: gpuProc
            command: [ "${pkgs.linuxPackages.nvidia_x11.settings}/bin/nvidia-settings", "-q", "GPUUtilization" ]
            running: false
            stdout: SplitParser {
                onRead: data => {
                    var m = /graphics=(\d+)/.exec(data);
                    if (m) root.gpuPercent = parseInt(m[1], 10);
                }
            }
        }

        Timer {
            interval: 2000; running: true; triggeredOnStart: true; repeat: true
            onTriggered: { statFile.reload(); memFile.reload(); gpuProc.running = true; }
        }
    }
  '';

  # One stat = icon + number. Reused four times rather than four near-copies.
  #
  # Root is an Item, not the Row itself: callers attach a MouseArea with
  # anchors.fill, and fill/centerIn anchors are illegal on a child of a Row —
  # Qt disables the whole layout rather than ignoring the anchor.
  quickshell.widgets.BarStat = ''
    import QtQuick
    import "../Common"

    Item {
        id: root

        property alias spacing: line.spacing

        implicitWidth:  line.implicitWidth
        implicitHeight: line.implicitHeight

        property string glyph:  ""
        property string value:  ""
        property bool   alert:  false
        property bool   filled: false
        property color  tint:   Glass.muted

        Row {
            id: line
            anchors.centerIn: parent
            // Tight: an icon and its own number are one thing. The gap
            // between separate stats (13) does the grouping.
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Glass.fontIcon
                font.pixelSize: 15
                font.variableAxes: root.filled ? Glass.iconActive : Glass.iconIdle
                color: root.alert ? Glass.critical : root.tint
                text:  root.glyph
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Glass.fontUi
                font.pixelSize: 12
                font.features: Glass.tnum
                color: root.alert ? Glass.critical : Glass.muted
                text:  root.value
            }
        }
    }
  '';

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

        property string glyph:   ""
        property int    value:   0
        property int    alertAt: 101
        property color  tint:    Glass.muted

        readonly property bool alert: value >= alertAt

        implicitWidth:  line.implicitWidth
        implicitHeight: line.implicitHeight

        Row {
            id: line
            anchors.centerIn: parent
            spacing: 5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Glass.fontIcon
                font.pixelSize: 15
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

  quickshell.modules.BarHardwareGroup = ''
    import QtQuick
    import "../Services"
    import "../Common"
    import "../Widgets"

    // developer_board was on the GPU and it is a circuit board — a generic
    // one, and close enough to the RAM DIMM beside it to be read as a second
    // stick. deployed_code is a cube: nothing in this font is a graphics
    // card, and "the thing that draws solids" is the honest association.
    // memory is the chip (CPU), memory_alt is the DIMM (RAM).
    Row {
        id: root
        spacing: 13

        property color accent: Glass.accentFallback

        BarStat {
            anchors.verticalCenter: parent.verticalCenter
            glyph:  Audio.muted ? "\ue04f" : "\ue050"
            value:  Audio.volume + "%"
            filled: !Audio.muted
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.MiddleButton) Audio.toggleMute();
                    else Qt.callLater(() => { Qt.openUrlExternally("pavucontrol"); })
                }
                onWheel: (wheel) => { Audio.setVolume(Audio.volume + (wheel.angleDelta.y > 0 ? 5 : -5)); }
            }
        }

        BarMeter {
            anchors.verticalCenter: parent.verticalCenter
            glyph:   "\uf720"
            value:   SystemStats.gpuPercent
            alertAt: 95
            tint:    root.accent
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

        BarPower {
            anchors.verticalCenter: parent.verticalCenter
            accent: root.accent
        }
    }
  '';
}

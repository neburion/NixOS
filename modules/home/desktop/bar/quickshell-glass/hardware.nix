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
            spacing: 6

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

  quickshell.modules.BarHardwareGroup = ''
    import QtQuick
    import "../Services"
    import "../Common"
    import "../Widgets"

    Row {
        id: root
        spacing: 13

        property color accent: Glass.accentFallback

        BarStat {
            anchors.verticalCenter: parent.verticalCenter
            glyph:  Audio.muted ? "" : ""
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

        BarStat {
            anchors.verticalCenter: parent.verticalCenter
            glyph: ""
            value: SystemStats.gpuPercent + "%"
            alert: SystemStats.gpuPercent >= 95
        }

        BarStat {
            anchors.verticalCenter: parent.verticalCenter
            glyph: ""
            value: SystemStats.cpuPercent + "%"
            alert: SystemStats.cpuPercent >= 90
        }

        BarStat {
            anchors.verticalCenter: parent.verticalCenter
            glyph: ""
            value: SystemStats.memPercent + "%"
            alert: SystemStats.memPercent >= 85
        }

        BarBattery {
            anchors.verticalCenter: parent.verticalCenter
            accent: root.accent
        }
    }
  '';
}

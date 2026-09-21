{ pkgs, ... }:

# SystemStats service + the right-hand stats cluster.
#
# The GPU reading came from `nvidia-settings -q GPUUtilization` and had never
# produced a number on this machine — it answers
#
#     ERROR: Error resolving target specification '' (No targets match ...)
#
# and the regex simply never matched, so gpuPercent sat at its initial 0 while
# the card was doing 15-50%. nvidia-settings talks to the X server's NV-CONTROL
# extension, which XWayland does not implement, so under Wayland it has no
# targets to resolve and never will. Measured against nvidia-smi it read 0
# through utilisation of 15, 21, 24, 36 and 50 percent.
#
# nvidia-smi needs no display and costs about 27ms. It comes from
# pkgs.linuxPackages.nvidia_x11, the same place the old nvidia-settings did;
# on this host that evaluates to the identical derivation as
# hardware.nvidia.package, checked rather than assumed.
#
# > A mismatched nvidia-smi refuses to talk to the driver at all. If this host
# > ever pins hardware.nvidia.package to something other than the default for
# > its kernel — a beta or production branch — this line has to follow it, and
# > the symptom is the GPU silently reading 0 again.
#
# CPU and RAM were checked at the same time and are right: against a reference
# reading /proc/stat on its own clock, cpuPercent tracked 37.5/56.4/51.0/44.8/
# 37.3 as 38/57/51/44/37, one sample behind because the two clocks are not in
# step. memPercent agrees with `free` to the point.

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
            command: [
                "${pkgs.linuxPackages.nvidia_x11.bin}/bin/nvidia-smi",
                "--query-gpu=utilization.gpu",
                "--format=csv,noheader,nounits"
            ]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    var n = parseInt(text.trim(), 10);
                    if (!isNaN(n)) root.gpuPercent = n;
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
            spacing: 5

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

  quickshell.modules.BarHardwareGroup = ''
    import QtQuick
    import "../Services"
    import "../Common"
    import "../Widgets"

    // Material Symbols has no graphics card. It has a circuit board
    // (developer_board, which sat here and read as a second RAM stick) and a
    // cube (deployed_code, which reads as 3D and not as hardware), and that is
    // the end of the shortlist. The nerd-patched face has the actual thing —
    // an expansion card with its connector edge — so the GPU borrows one
    // glyph from it and nothing else does.
    //
    // It is a filled glyph among outlines, so it is set a size smaller to
    // carry the same weight. Codepoint via String.fromCodePoint: U+F08AE sits
    // in Plane 15, and a "\u" escape takes four hex digits and would eat it.
    //
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

        BarPower {
            anchors.verticalCenter: parent.verticalCenter
            accent: root.accent
        }
    }
  '';
}

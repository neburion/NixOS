{ pkgs, ... }:

# SystemStats service, the audio stat, and the cluster that lines the three
# of them up. The three load meters and their menu are in loads.nix.
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

        // Detail, read on the same tick and only ever shown in the menu.
        property string cpuModel:  ""
        property string loadAvg:   ""
        property int    cpuTemp:   0

        property string gpuName:     ""
        property int    gpuMemUsed:  0   // MiB
        property int    gpuMemTotal: 0
        property int    gpuTemp:     0
        property int    gpuClock:    0

        property real memUsedGiB:   0
        property real memTotalGiB:  0
        property real swapUsedGiB:  0
        property real swapTotalGiB: 0

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
                function kb(key) {
                    var m = new RegExp(key + ":\\s+(\\d+)").exec(t);
                    return m ? parseInt(m[1], 10) : 0;
                }
                var total = kb("MemTotal");
                var avail = kb("MemAvailable");
                if (total && avail) {
                    root.memPercent  = Math.round((1 - avail / total) * 100);
                    root.memTotalGiB = total / 1048576;
                    root.memUsedGiB  = (total - avail) / 1048576;
                }
                var swTotal = kb("SwapTotal");
                var swFree  = kb("SwapFree");
                root.swapTotalGiB = swTotal / 1048576;
                root.swapUsedGiB  = (swTotal - swFree) / 1048576;
            }
        }

        // Read once. The model name does not change, and /proc/cpuinfo is
        // 20 cores' worth of text to re-parse every two seconds for it.
        FileView {
            path: "/proc/cpuinfo"
            watchChanges: false
            onLoaded: {
                var m = /model name\s*:\s*(.+)/.exec(text());
                // "13th Gen Intel(R) Core(TM) i9-13900H" is mostly legal
                // boilerplate; the menu has one line for this.
                if (m) root.cpuModel = m[1].replace(/\((R|TM)\)/g, "")
                                           .replace(/\s+/g, " ").trim();
            }
        }

        FileView {
            id: loadFile
            path: "/proc/loadavg"
            watchChanges: false
            onLoaded: {
                var f = text().trim().split(/\s+/);
                if (f.length >= 3) root.loadAvg = f[0] + "  " + f[1] + "  " + f[2];
            }
        }

        // hwmon numbering is not stable across boots, so the coretemp node is
        // found once by name and the FileView follows the answer. Globbing on
        // every tick would mean a shell spawn every two seconds for one int.
        property string cpuTempPath: ""

        Process {
            running: true
            command: ["sh", "-c",
                "for h in /sys/class/hwmon/hwmon*; do " +
                "[ \"$(cat \"$h/name\" 2>/dev/null)\" = coretemp ] && " +
                "{ echo \"$h/temp1_input\"; break; }; done"]
            stdout: StdioCollector { onStreamFinished: root.cpuTempPath = text.trim() }
        }

        FileView {
            id: tempFile
            path: root.cpuTempPath
            watchChanges: false
            onLoaded: {
                var n = parseInt(text().trim(), 10);
                if (!isNaN(n)) root.cpuTemp = Math.round(n / 1000);
            }
        }

        Process {
            id: gpuProc
            command: [
                "${pkgs.linuxPackages.nvidia_x11.bin}/bin/nvidia-smi",
                "--query-gpu=utilization.gpu,memory.used,memory.total," +
                "temperature.gpu,clocks.gr,name",
                "--format=csv,noheader,nounits"
            ]
            running: false
            stdout: StdioCollector {
                // One call for all six: the extra fields are free next to the
                // process spawn, and the name is last because it is the only
                // one that could ever contain a comma.
                onStreamFinished: {
                    var f = text.trim().split(",");
                    if (f.length < 6) return;
                    var n = parseInt(f[0], 10);
                    if (!isNaN(n)) root.gpuPercent = n;
                    root.gpuMemUsed  = parseInt(f[1], 10) || 0;
                    root.gpuMemTotal = parseInt(f[2], 10) || 0;
                    root.gpuTemp     = parseInt(f[3], 10) || 0;
                    root.gpuClock    = parseInt(f[4], 10) || 0;
                    root.gpuName     = f.slice(5).join(",").trim()
                                        .replace(/^NVIDIA GeForce /, "");
                }
            }
        }

        Timer {
            interval: 2000; running: true; triggeredOnStart: true; repeat: true
            onTriggered: {
                statFile.reload(); memFile.reload();
                loadFile.reload(); tempFile.reload();
                gpuProc.running = true;
            }
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

        BarLoads {
            anchors.verticalCenter: parent.verticalCenter
            accent: root.accent
        }

        BarPower {
            anchors.verticalCenter: parent.verticalCenter
            accent: root.accent
        }
    }
  '';
}

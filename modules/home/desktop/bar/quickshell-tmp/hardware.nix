{ pkgs, ... }:

# SystemStats service + hardware group. Sepia text, no capsule backgrounds.

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

  quickshell.modules.BarHardwareGroup = ''
    import QtQuick
    import QtQuick.Layouts
    import "../Services"
    import "../Common"

    RowLayout {
        spacing: 12

        Text {
            font.family: "FiraMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fg
            text:  (Audio.muted ? "󰝟" : "󰕾") + " " + Audio.volume + "%"
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

        Text {
            font.family: "FiraMono Nerd Font"
            font.pixelSize: 13
            color: Theme.fg
            text:  "󰢮 " + SystemStats.gpuPercent + "%"
        }

        Text {
            font.family: "FiraMono Nerd Font"
            font.pixelSize: 13
            color: SystemStats.cpuPercent >= 90 ? Theme.warning : Theme.fg
            text:  "󰍛 " + SystemStats.cpuPercent + "%"
        }

        Text {
            font.family: "FiraMono Nerd Font"
            font.pixelSize: 13
            color: SystemStats.memPercent >= 80 ? Theme.warning : Theme.fg
            text:  " " + SystemStats.memPercent + "%"
        }

        BarBattery { }
    }
  '';
}

{ ... }:

# The Razer Nari Essential, through its dongle's vendor feature report.
#
# The reader lives in modules/home/peripherals/razer-nari/ and costs two
# ioctls, so this one can poll every couple of minutes. It exits non-zero when
# the headset is off, which arrives here as absence rather than as zero.
#
# The caption is the voltage, deliberately: that is the measurement. The
# percentage is a Li-ion curve read backwards from it, so the number the ring
# draws is an estimate and the reading it came from stays visible beside it.

{
  quickshell.services.HeadsetBattery = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        property int  percent:    0
        property int  millivolts: 0
        property bool present:    false

        readonly property string caption:
            root.present ? (root.millivolts / 1000).toFixed(2) + " V" : "Off"

        Process {
            id: proc
            command: ["nari-battery"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    var m = /^(\d+) (\d+)$/.exec(text.split("\n")[0].trim());
                    root.present = !!m;
                    if (m) {
                        root.percent    = parseInt(m[1], 10);
                        root.millivolts = parseInt(m[2], 10);
                    }
                }
            }
        }

        function refresh() { if (!proc.running) proc.running = true; }

        Timer {
            interval: 120000; running: true; triggeredOnStart: true; repeat: true
            onTriggered: root.refresh()
        }
    }
  '';

  quickshell.powerSources.headset = {
    order = 30;
    reading = ''
      ({
          label:   "Nari Essential",
          present: HeadsetBattery.present,
          value:   HeadsetBattery.percent,
          caption: HeadsetBattery.caption
      })
    '';
    refresh = "HeadsetBattery.refresh();";
  };
}

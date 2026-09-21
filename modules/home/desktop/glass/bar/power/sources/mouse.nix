{ ... }:

# The Logitech mouse, through solaar.
#
# The reader lives in modules/home/peripherals/logitech/ and is invoked by
# bare name off PATH, which keeps the coupling soft: without that module
# imported the Process comes back empty, `present` stays false, and the ring
# is simply not drawn.
#
# It costs about five seconds a call — a Python start plus a full HID++
# feature enumeration — so it polls every ten minutes and again on demand
# when the menu opens, which is the only moment the number has to be fresh.

{
  quickshell.services.MouseBattery = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        property string name:    ""
        property int    percent: 0
        property string state:   ""
        property bool   present: false

        readonly property bool charging: state === "charging" || state === "recharging"

        // solaar's BatteryStatus enum, as a caption: SLOW_RECHARGE -> "Slow recharge".
        readonly property string caption: {
            if (!root.present) return "Not connected";
            var s = root.state.replace(/_/g, " ");
            return s.charAt(0).toUpperCase() + s.slice(1);
        }

        Process {
            id: proc
            command: ["logitech-battery"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    // One line per device; this receiver pairs one mouse.
                    var m = /^(\d+) (\S+) (.+)$/.exec(text.split("\n")[0].trim());
                    root.present = !!m;
                    if (m) {
                        root.percent = parseInt(m[1], 10);
                        root.state   = m[2];
                        root.name    = m[3];
                    }
                }
            }
        }

        // Never started on top of a running read: an empty answer means
        // absence, and a cancelled read answers empty.
        function refresh() { if (!proc.running) proc.running = true; }

        Timer {
            interval: 600000; running: true; triggeredOnStart: true; repeat: true
            onTriggered: root.refresh()
        }
    }
  '';

  quickshell.powerSources.mouse = {
    order = 20;
    reading = ''
      ({
          label:   MouseBattery.present ? MouseBattery.name : "Mouse",
          present: MouseBattery.present,
          value:   MouseBattery.percent,
          caption: MouseBattery.caption
      })
    '';
    refresh = "MouseBattery.refresh();";
  };
}

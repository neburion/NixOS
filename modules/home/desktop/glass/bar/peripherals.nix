{ ... }:

# Peripherals: the mouse and the headset, as two readings. Nothing here draws
# anything — power.nix owns the dial that shows them beside the laptop's cell.
#
# The two readers live in modules/home/peripherals/, not here — they are
# useful at a prompt with no bar running at all, and they answer for hardware
# that outlives any desktop. Invoked by bare name off PATH, which also makes
# the coupling soft: without the peripherals preset imported, both Processes
# come back empty, both devices stay null, and their rings draw as empty
# tracks rather than erroring.
#
# Poll rates are set by what each reader costs. nari-battery is two ioctls, so
# it can run every couple of minutes. logitech-battery is a Python start plus
# a full HID++ feature enumeration — about five seconds — so it runs every ten
# minutes and on demand when the menu opens, which is the only moment the
# number has to be fresh.

{
  quickshell.services.Peripherals = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        // { label, caption, percent, charging }, or null when absent.
        property var mouse:   null
        property var headset: null

        property bool busy: false

        // solaar's BatteryStatus enum, as a caption: SLOW_RECHARGE -> "Slow recharge".
        function titled(state) {
            var s = state.replace(/_/g, " ");
            return s.charAt(0).toUpperCase() + s.slice(1);
        }

        Process {
            id: mouseProc
            command: ["logitech-battery"]
            running: false
            onExited: { root.busy = false; busyGuard.stop(); }
            stdout: StdioCollector {
                onStreamFinished: {
                    // One line per device; this receiver pairs one mouse.
                    var m = /^(\d+) (\S+) (.+)$/.exec(text.split("\n")[0].trim());
                    root.mouse = m ? ({
                        label:    m[3],
                        caption:  root.titled(m[2]),
                        percent:  parseInt(m[1], 10),
                        charging: m[2] === "charging" || m[2] === "recharging"
                    }) : null;
                }
            }
        }

        Process {
            id: headsetProc
            command: ["nari-battery"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    var m = /^(\d+) (\d+)$/.exec(text.split("\n")[0].trim());
                    root.headset = m ? ({
                        label:   "Nari Essential",
                        // The voltage is the measurement; the percent is a
                        // Li-ion curve read backwards from it. The caption
                        // carries the datum so the estimate can be judged.
                        caption: (parseInt(m[2], 10) / 1000).toFixed(2) + " V",
                        percent: parseInt(m[1], 10),
                        charging: false
                    }) : null;
                }
            }
        }

        // Guarded, because a reader that comes back empty is read as absence
        // and clears its device. A read is never started on top of a running
        // one, so a slow tick cannot cancel a fresh answer.
        function readMouse()   { if (!mouseProc.running)   mouseProc.running   = true; }
        function readHeadset() { if (!headsetProc.running) headsetProc.running = true; }

        function refresh() {
            root.busy = true;
            root.readMouse();
            root.readHeadset();
            busyGuard.restart();
        }

        // `busy` is cosmetic, so it must never be the thing that wedges. If
        // the reader never reports an exit — missing from PATH, say — the
        // guard releases it anyway.
        Timer { id: busyGuard; interval: 20000; repeat: false; onTriggered: root.busy = false }

        // One clock rather than two, so the first tick cannot collide with
        // itself. The headset rides every tick; the mouse, at five seconds a
        // read, rides every fifth.
        property int tick: 0

        Timer {
            interval: 120000; running: true; triggeredOnStart: true; repeat: true
            onTriggered: {
                root.readHeadset();
                if (root.tick % 5 === 0) root.readMouse();
                root.tick++;
            }
        }
    }
  '';
}

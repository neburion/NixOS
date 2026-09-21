{ ... }:

# Peripherals service + the charge readout that sits beside the laptop's own
# battery, and the menu behind it.
#
# The two readers live in modules/home/peripherals/, not here — they are
# useful at a prompt with no bar running at all, and they answer for hardware
# that outlives any desktop. This file only draws what they say. Invoked by
# bare name off PATH, which also makes the coupling soft: without the
# peripherals preset imported, both Processes come back empty, `present` goes
# false and the widget disappears rather than erroring.
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

        // { glyph, label, caption, percent, charging }
        property var mouse:   null
        property var headset: null

        // Sorted lowest-first, so devices[0] is the one the bar reports and
        // the one worth worrying about.
        property var devices: []

        readonly property bool present:  devices.length > 0
        readonly property int  worst:    present ? devices[0].percent : 0
        readonly property string glyph:  present ? devices[0].glyph   : ""
        readonly property bool charging: (mouse   && mouse.charging)
                                      || (headset && headset.charging)

        property bool busy: false

        function rebuild() {
            var out = [];
            if (root.mouse)   out.push(root.mouse);
            if (root.headset) out.push(root.headset);
            out.sort(function (a, b) { return a.percent - b.percent; });
            root.devices = out;
        }

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
                        glyph:    "",
                        label:    m[3],
                        caption:  root.titled(m[2]),
                        percent:  parseInt(m[1], 10),
                        charging: m[2] === "charging" || m[2] === "recharging"
                    }) : null;
                    root.rebuild();
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
                        glyph:   "",
                        label:   "Nari Essential",
                        // The voltage is the measurement; the percent is a
                        // Li-ion curve read backwards from it. The caption
                        // carries the datum so the estimate can be judged.
                        caption: (parseInt(m[2], 10) / 1000).toFixed(2) + " V",
                        percent: parseInt(m[1], 10),
                        charging: false
                    }) : null;
                    root.rebuild();
                }
            }
        }

        // Guarded, because a reader that comes back empty is read as absence
        // and clears its device. Two nari-battery processes overlapping on
        // the same hidraw node is exactly how a present headset produces an
        // empty frame, so a read is never started on top of a running one.
        function readMouse()   { if (!mouseProc.running)   mouseProc.running   = true; }
        function readHeadset() { if (!headsetProc.running) headsetProc.running = true; }

        function refresh() {
            root.busy = true;
            root.readMouse();
            root.readHeadset();
            busyGuard.restart();
        }

        // `busy` only greys out the menu's button, so it must never be the
        // thing that wedges. If the reader never reports an exit — missing
        // from PATH, say — the guard releases it anyway.
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

  # A popup row that reports rather than acts: no tap target, a number instead
  # of a trailing glyph, and a meter under it. Lives here and not in
  # popup-widgets.nix because this is the only menu built out of readings.
  quickshell.widgets.PopupMeter = ''
    import QtQuick
    import "../Common"

    Item {
        id: root
        height: 46

        property string glyph:   ""
        property string label:   ""
        property string caption: ""
        property int    percent: 0
        property color  tint:    Glass.muted

        readonly property bool low: percent <= 20

        Text {
            id: icon
            anchors { left: parent.left; leftMargin: 10; top: parent.top; topMargin: 3 }
            font.family: Glass.fontIcon
            font.pixelSize: 16
            font.variableAxes: Glass.iconIdle
            color: root.low ? Glass.critical : Glass.muted
            text:  root.glyph
        }

        Text {
            id: value
            anchors { right: parent.right; rightMargin: 10; top: parent.top; topMargin: 3 }
            font.family: Glass.fontUi
            font.pixelSize: 13
            font.features: Glass.tnum
            color: root.low ? Glass.critical : Glass.text
            text:  root.percent + "%"
        }

        Text {
            id: name
            anchors {
                left:  icon.right; leftMargin: 10
                right: value.left; rightMargin: 8
                baseline: value.baseline
            }
            font.family: Glass.fontUi
            font.pixelSize: 13
            font.letterSpacing: -0.1
            color: Glass.text
            text:  root.label
            elide: Text.ElideRight
        }

        Text {
            anchors { left: name.left; top: name.bottom; topMargin: 1 }
            font.family: Glass.fontUi
            font.pixelSize: 11
            color: Glass.faint
            text:  root.caption
        }

        Rectangle {
            anchors {
                left: name.left; right: parent.right; rightMargin: 10
                bottom: parent.bottom; bottomMargin: 6
            }
            height: 3
            radius: 1.5
            color: Qt.rgba(1, 1, 1, 0.09)

            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width:  parent.width * Math.max(0, Math.min(100, root.percent)) / 100
                radius: 1.5
                color:  root.low ? Glass.critical : root.tint
                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            }
        }
    }
  '';

  quickshell.modules.BarPeripherals = ''
    import Quickshell
    import QtQuick
    import "../Services"
    import "../Common"
    import "../Widgets"

    Item {
        id: root
        visible: Peripherals.present
        implicitWidth:  visible ? stat.implicitWidth  : 0
        implicitHeight: visible ? stat.implicitHeight : 0

        property color accent: Glass.accentFallback

        // The bar carries the lowest of them. Which device that is changes,
        // so the glyph changes with it — a mouse at 12% has to be able to say
        // so without the menu open.
        BarStat {
            id: stat
            anchors.centerIn: parent
            glyph:  Peripherals.glyph
            value:  Peripherals.worst + "%"
            alert:  Peripherals.worst <= 20
            filled: Peripherals.charging
        }

        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onClicked: {
                var opening = PopupState.owner !== root;
                PopupState.toggle(root);
                if (opening) Peripherals.refresh();
            }
        }

        PopupWindow {
            id: popup
            visible: PopupState.owner === root
            grabFocus: true
            onClosed: if (PopupState.owner === root) PopupState.close()
            color: "transparent"
            implicitWidth: 280
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
                    spacing: 6

                    // No power switch to offer — these are readings. The
                    // header's toggle is left off rather than wired to
                    // something it does not control.
                    Text {
                        height: 30
                        verticalAlignment: Text.AlignVCenter
                        font.family: Glass.fontUi
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.letterSpacing: -0.13
                        color: Glass.text
                        text:  "Peripherals"
                    }

                    Column {
                        width: parent.width; spacing: 2

                        Repeater {
                            model: Peripherals.devices
                            delegate: PopupMeter {
                                required property var modelData
                                width:   col.width
                                glyph:   modelData.glyph
                                label:   modelData.label
                                caption: modelData.charging ? "Charging" : modelData.caption
                                percent: modelData.percent
                                tint:    root.accent
                            }
                        }

                        PopupEmpty {
                            width: parent.width
                            visible: !Peripherals.present
                            label: "Nothing connected"
                        }
                    }

                    PopupAction {
                        width: parent.width
                        glyph: ""
                        label: Peripherals.busy ? "Reading…" : "Refresh"
                        enabled: !Peripherals.busy
                        onActivated: Peripherals.refresh()
                    }
                }
            }
        }
    }
  '';
}

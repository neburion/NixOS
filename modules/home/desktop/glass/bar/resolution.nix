{ lib, hostConfig, ... }:

# Apparent size, as a bar menu.
#
# Structure is the tray's, because the problem is the tray's: a list of things,
# each of which has its own list underneath it. One icon, one popup, one focus
# grab; clicking an output expands its sizes below a separator, and nothing is
# ever nested in a second popup.
#
# Every row is a whole-number divisor of that output's native mode, and there is
# nothing else on offer. The panel is always driven natively and a smaller
# desktop is a compositor scale, so each row is pixel-exact by construction —
# 2560x1440 is absent from a 4K panel's list because 1.5:1 has no sharp form.
# wm/resolution.nix explains the arithmetic; this file only draws it.
#
# The rows are therefore NOT read from the output's mode list. That list is full
# of modes the panel would have to stretch, which is precisely what is being
# avoided, so the sizes are derived from the declared native mode instead.

let
  parseMode = s:
    let
      parts = lib.splitString "@" s;
      res   = lib.splitString "x" (builtins.head parts);
      rate  = builtins.elemAt parts 1;
    in {
      w = lib.toInt (builtins.head res);
      h = lib.toInt (builtins.elemAt res 1);
      r = lib.toInt (builtins.head (lib.splitString "." rate));
    };

  natives = builtins.toJSON (lib.mapAttrs'
    (_: m: lib.nameValuePair m.name (parseMode m.mode))
    hostConfig.displays.monitors);
in
{
  quickshell.services.MonitorModes = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        // [{ name, current, rate, sizes: [{ size, label, ratio, active }] }]
        property var outputs: []

        // Each declared output's native mode, from displays.nix.
        readonly property var natives: (${natives})

        // Below this a desktop is not usable, and on a 4K panel it is also the
        // point where the next whole divisor (960 wide, 4:1) would appear.
        readonly property int minWidth: 1280

        function refresh() { probe.running = true; }

        Process {
            id: probe
            running: false
            command: ["hyprctl", "-j", "monitors"]
            stdout: StdioCollector {
                onStreamFinished: root.outputs = root.parse(text)
            }
        }

        function parse(raw) {
            var mons;
            try {
                mons = JSON.parse(raw);
            } catch (e) {
                return [];
            }

            var out = [];
            for (var i = 0; i < mons.length; i++) {
                var mon = mons[i];

                // An undeclared output still has a native mode: the one it is
                // running. Falling back to it keeps a newly plugged-in monitor
                // from showing an empty list.
                var native = root.natives[mon.name]
                    || ({ w: mon.width, h: mon.height, r: Math.round(mon.refreshRate) });

                // What the desktop currently measures, which is the mode divided
                // by the scale — not the mode. At scale 2 a 4K output is a
                // 1920x1080 desktop, and that is the row that should be ticked.
                var scale = mon.scale || 1;
                var logicalW = Math.round(mon.width / scale);
                var logicalH = Math.round(mon.height / scale);

                var sizes = [];
                for (var n = 1; native.w / n >= root.minWidth; n++) {
                    if (native.w % n || native.h % n)
                        continue;
                    var w = native.w / n;
                    var h = native.h / n;
                    sizes.push({
                        size:   w + "x" + h,
                        label:  w + " × " + h,
                        ratio:  n + ":1",
                        active: w === logicalW && h === logicalH
                    });
                }

                out.push({
                    name:    mon.name,
                    current: logicalW + " × " + logicalH,
                    rate:    Math.round(mon.refreshRate) + " Hz",
                    sizes:   sizes
                });
            }
            return out;
        }

        // One output's rows, or none. Here rather than as a binding in the bar
        // module: a property bound to a statement block is only evaluated when
        // the popup first becomes visible, which is a poor place to discover a
        // mistake. Reading `outputs` inside a plain function still registers the
        // dependency, so the caller's binding tracks it either way.
        function sizesFor(name) {
            for (var i = 0; i < root.outputs.length; i++)
                if (root.outputs[i].name === name)
                    return root.outputs[i].sizes;
            return [];
        }

        // The wallpaper has to be re-sent afterwards, for the same reason a
        // rotation does: awww holds the image at the geometry it was given, so
        // an output whose logical size just halved keeps showing a frame drawn
        // for the old one. The sleep is for the change to retire — re-sending
        // into the old geometry only reproduces the stretch. mpvpaper is killed
        // first because glass-wallpaper-restore starts one unconditionally, and
        // a live wallpaper would otherwise end up with two.
        function apply(name, size) {
            applier.command = [
                "sh", "-c",
                "set-monitor-size \"$1\" \"$2\" || exit 0; " +
                "sleep 1; " +
                "pkill -f \"mpvpaper .*$1\" >/dev/null 2>&1; " +
                "glass-wallpaper-restore \"$1\"",
                "sh", name, size
            ];
            applier.running = true;
            settle.restart();
        }

        Process { id: applier; running: false }

        // Re-read after a change lands, so a popup left open stops claiming the
        // old size is current.
        Timer {
            id: settle
            interval: 2500
            repeat: false
            onTriggered: root.refresh()
        }
    }
  '';

  quickshell.modules.BarResolution = ''
    import Quickshell
    import QtQuick
    import "../Common"
    import "../Services"
    import "../Widgets"

    Item {
        id: root
        implicitHeight: 20
        implicitWidth:  chip.implicitWidth

        // Which output's size list is expanded, or "".
        property string expanded: ""

        readonly property var expandedSizes: MonitorModes.sizesFor(root.expanded)

        Text {
            id: chip
            anchors.centerIn: parent
            font.family: Glass.fontIcon
            font.pixelSize: 17
            font.variableAxes: PopupState.owner === root ? Glass.iconActive : Glass.iconIdle
            color: PopupState.owner === root ? Glass.text : Glass.muted
            // aspect_ratio
            text: "\ue85b"
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                var opening = PopupState.owner !== root;
                PopupState.toggle(root);
                if (opening) {
                    root.expanded = "";
                    MonitorModes.refresh();
                }
            }
        }

        PopupWindow {
            id: popup
            visible: PopupState.owner === root
            grabFocus: true
            onClosed: {
                if (PopupState.owner === root) PopupState.close();
                root.expanded = "";
            }
            color: "transparent"
            implicitWidth:  288
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

                    Text {
                        height: 20
                        font.family: Glass.fontUi
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.letterSpacing: -0.13
                        color: Glass.text
                        text: "Display size"
                    }

                    // ---- outputs ----
                    Column {
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: MonitorModes.outputs
                            delegate: PopupRow {
                                required property var modelData
                                width: col.width
                                // monitor
                                glyph:  "\uef5b"
                                label:  modelData.name + "  ·  " + modelData.current
                                active: root.expanded === modelData.name
                                // expand_more / chevron_right
                                trailing: root.expanded === modelData.name ? "\ue5cf" : "\ue409"
                                onActivated: root.expanded =
                                    root.expanded === modelData.name ? "" : modelData.name
                            }
                        }

                        PopupEmpty {
                            width: parent.width
                            visible: MonitorModes.outputs.length === 0
                            label: "Reading outputs…"
                        }
                    }

                    Rectangle {
                        visible: root.expanded !== ""
                        width: parent.width
                        height: 1
                        color: Glass.stroke
                    }

                    // ---- that output's sizes ----
                    Column {
                        visible: root.expanded !== ""
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: root.expandedSizes
                            delegate: PopupRow {
                                required property var modelData
                                width: col.width
                                // aspect_ratio
                                glyph:  "\ue85b"
                                label:  modelData.label + "  ·  " + modelData.ratio
                                active: modelData.active
                                // check
                                trailing: modelData.active ? "\ue5ca" : ""
                                onActivated: {
                                    if (!modelData.active)
                                        MonitorModes.apply(root.expanded, modelData.size);
                                    PopupState.close();
                                    root.expanded = "";
                                }
                            }
                        }
                    }
                }
            }
        }
    }
  '';
}

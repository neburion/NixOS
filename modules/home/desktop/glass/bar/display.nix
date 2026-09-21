{ lib, hostConfig, ... }:

# Everything about the displays, as one bar menu: what each output is set to,
# what else it can do, and which way round it is.
#
# Rotation used to be its own bar icon next to this one, which meant two
# controls for one subject and a toggle that could not say which output it
# applied to. It is a row in the expanded section now, shown only for the
# output that can actually rotate.
#
# Structure is the tray's, because the problem is the tray's: a list of things,
# each of which has its own list underneath it. One icon, one popup, one focus
# grab; clicking an output expands its rows below a separator, and nothing is
# ever nested in a second popup.
#
# The mode list is filtered hard on purpose. HDMI-A-1 advertises thirty-five
# modes, twenty of which are 4:3 relics and five of which are the same
# resolution at a slower refresh. What lands in the popup is one row per
# resolution at its highest refresh, floored at 1280 wide and capped at that
# output's declared ceiling — seven rows for the 32", three for the panels.
#
# Nothing here computes geometry. set-monitor-mode writes one state file and
# reflow-monitors decides where the outputs end up; see wm/monitor-layout.nix.

let
  # Declared maxima, per output, pre-parsed for the JS filter.
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

  ceilings = builtins.toJSON (lib.mapAttrs'
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

        // [{ name, current, rate, modes: [{ mode, label, rate, active }] }]
        property var outputs: []

        readonly property var ceilings: (${ceilings})

        // Below this, a "resolution" is a thing you set by accident.
        readonly property int minWidth: 1280

        // A fixed-pixel panel can only letterbox or stretch a mode that is not
        // its own shape, so only modes matching the output's aspect are offered.
        // Without this the 16:9 LG lists eight rows, seven of them 16:10 and 4:3
        // relics from the VESA table.
        readonly property real aspectTolerance: 0.02

        function refresh() { probe.running = true; }

        Process {
            id: probe
            running: false
            command: ["hyprctl", "-j", "monitors"]
            stdout: StdioCollector {
                onStreamFinished: root.outputs = root.parse(text)
            }
        }

        function parseMode(s) {
            var m = /^(\d+)x(\d+)@([\d.]+)Hz?$/.exec(s.trim());
            if (!m)
                return null;
            return { w: parseInt(m[1]), h: parseInt(m[2]), r: Math.round(parseFloat(m[3])) };
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
                var cap = root.ceilings[mon.name];
                var list = mon.availableModes || [];

                // The ceiling's shape where one is declared, the running mode's
                // otherwise — an output nobody declared still has an aspect.
                var aspect = cap ? (cap.w / cap.h) : (mon.width / mon.height);

                // One entry per resolution, keeping its fastest refresh.
                var best = ({});
                for (var j = 0; j < list.length; j++) {
                    var mode = root.parseMode(list[j]);
                    if (!mode || mode.w < root.minWidth)
                        continue;
                    if (cap && (mode.w > cap.w || mode.h > cap.h || mode.r > cap.r))
                        continue;
                    if (Math.abs(mode.w / mode.h - aspect) > root.aspectTolerance)
                        continue;
                    var key = mode.w + "x" + mode.h;
                    if (best[key] === undefined || mode.r > best[key])
                        best[key] = mode.r;
                }

                var dims = [];
                for (var k in best)
                    dims.push({ w: parseInt(k.split("x")[0]),
                                h: parseInt(k.split("x")[1]),
                                r: best[k] });
                dims.sort(function (a, b) { return (b.w - a.w) || (b.h - a.h); });

                var rows = [];
                for (var d = 0; d < dims.length; d++) {
                    rows.push({
                        mode:  dims[d].w + "x" + dims[d].h + "@" + dims[d].r,
                        label: dims[d].w + " × " + dims[d].h,
                        rate:  dims[d].r + " Hz",
                        // Matched on resolution alone. Only one refresh per
                        // resolution is offered, so a monitor sitting at 4K@60
                        // would otherwise show no active row at all.
                        active: dims[d].w === mon.width && dims[d].h === mon.height
                    });
                }

                out.push({
                    name:    mon.name,
                    current: mon.width + " × " + mon.height,
                    rate:    Math.round(mon.refreshRate) + " Hz",
                    modes:   rows
                });
            }
            return out;
        }

        // One output's rows, or none. Here rather than as a binding in the bar
        // module: a property bound to a statement block is only evaluated when
        // the popup first becomes visible, which is a poor place to discover a
        // mistake. Reading `outputs` inside a plain function still registers the
        // dependency, so the caller's binding tracks it either way.
        function modesFor(name) {
            for (var i = 0; i < root.outputs.length; i++)
                if (root.outputs[i].name === name)
                    return root.outputs[i].modes;
            return [];
        }

        // The wallpaper has to be re-sent afterwards, for the same reason a
        // rotation does: awww holds the image at the geometry it was given, so
        // an output that has just dropped to 1440p keeps showing the 4K frame
        // scaled to fit. The sleep is for the modeset to retire — re-sending
        // into the old geometry only reproduces the stretch. mpvpaper is killed
        // first because glass-wallpaper-restore starts one unconditionally, and
        // a live wallpaper would otherwise end up with two.
        function apply(name, mode) {
            applier.command = [
                "sh", "-c",
                "set-monitor-mode \"$1\" \"$2\" || exit 0; " +
                "sleep 1; " +
                "pkill -f \"mpvpaper .*$1\" >/dev/null 2>&1; " +
                "glass-wallpaper-restore \"$1\"",
                "sh", name, mode
            ];
            applier.running = true;
            settle.restart();
        }

        Process { id: applier; running: false }

        // Re-read after a change lands, so a popup left open stops claiming the
        // old mode is current.
        Timer {
            id: settle
            interval: 2500
            repeat: false
            onTriggered: root.refresh()
        }
    }
  '';

  quickshell.modules.BarDisplay = ''
    import Quickshell
    import Quickshell.Io
    import QtQuick
    import "../Common"
    import "../Services"
    import "../Widgets"

    Item {
        id: root
        implicitHeight: 20
        implicitWidth:  chip.implicitWidth

        // Which output's mode list is expanded, or "".
        property string expanded: ""

        readonly property var expandedModes: MonitorModes.modesFor(root.expanded)

        Process { id: refresher; running: false }

        // The wallpaper has to be re-sent afterwards, for the same reason a
        // mode change does: awww holds the image at the geometry it was given,
        // so a screen that has just gone portrait keeps showing the landscape
        // frame stretched to fit. The delay is for the reflow to settle —
        // re-sending into the old geometry only reproduces the stretch.
        function rotate() {
            MonitorRotation.toggle();
            refresher.command = [
                "sh", "-c",
                "sleep 1; glass-wallpaper-restore \"$1\"",
                "sh", MonitorRotation.monName
            ];
            refresher.running = true;
        }

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
                        text: "Display"
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

                    // ---- that output's orientation and modes ----
                    Column {
                        visible: root.expanded !== ""
                        width: parent.width
                        spacing: 2

                        // Only the external monitor has a persisted transform,
                        // so only it gets the row. MonitorRotation watches the
                        // state file, so the label follows a rotation done from
                        // the keybind too.
                        PopupRow {
                            width: col.width
                            visible: root.expanded === MonitorRotation.monName
                            // mobile_rotate
                            glyph:  "\uf2d5"
                            label:  "Orientation  ·  " + (MonitorRotation.transform !== 0
                                                          ? "Portrait" : "Landscape")
                            active: MonitorRotation.transform !== 0
                            // mobile / mobile_landscape
                            trailing: MonitorRotation.transform !== 0 ? "\ue7ba" : "\ued3e"
                            onActivated: root.rotate()
                        }

                        Rectangle {
                            visible: root.expanded === MonitorRotation.monName
                            width: parent.width
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.06)
                        }

                        Repeater {
                            model: root.expandedModes
                            delegate: PopupRow {
                                required property var modelData
                                width: col.width
                                // aspect_ratio
                                glyph:  "\ue85b"
                                label:  modelData.label + "  ·  " + modelData.rate
                                active: modelData.active
                                // check
                                trailing: modelData.active ? "\ue5ca" : ""
                                onActivated: {
                                    if (!modelData.active)
                                        MonitorModes.apply(root.expanded, modelData.mode);
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

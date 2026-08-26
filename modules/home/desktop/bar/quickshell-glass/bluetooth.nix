{ ... }:

# BluetoothState service (verbatim from clean) + glass Bluetooth indicator and popup.

{
  quickshell.services.BluetoothState = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        property bool powered:        false
        property int  connectedCount: 0
        property var  devices:        []
        property bool scanning:       false

        Process {
            id: powerProc; running: false
            command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -m1 'Powered:' | awk '{print $2}'"]
            stdout: SplitParser {
                onRead: data => {
                    root.powered = data.trim() === "yes";
                    if (root.powered) { countProc.running = true; devicesProc.running = true; }
                    else { root.connectedCount = 0; root.devices = []; }
                }
            }
        }

        Process {
            id: countProc; running: false
            command: ["sh", "-c", "bluetoothctl devices Connected 2>/dev/null | wc -l"]
            stdout: SplitParser { onRead: data => { root.connectedCount = parseInt(data.trim()) || 0; } }
        }

        Process {
            id: devicesProc; running: false
            command: ["sh", "-c",
                "bluetoothctl devices 2>/dev/null | while read _ mac name; do "
                + "connected=$(bluetoothctl info \"$mac\" 2>/dev/null | grep -m1 'Connected:' | awk '{print $2}'); "
                + "echo \"$connected|$mac|$name\"; "
                + "done"]
            stdout: StdioCollector {
                onStreamFinished: {
                    var devs = []; var lines = text.split("\n");
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i]; if (!line) continue;
                        var p = line.split("|"); if (p.length < 3) continue;
                        devs.push({ connected: p[0] === "yes", mac: p[1], name: p.slice(2).join("|") });
                    }
                    devs.sort(function(a, b) {
                        if (a.connected !== b.connected) return a.connected ? -1 : 1;
                        return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
                    });
                    root.devices = devs;
                }
            }
        }

        Process { id: btCtl; running: false; onExited: { root.refresh() } }
        Process {
            id: scanCtl; running: false
            command: ["bluetoothctl", "--timeout", "5", "scan", "on"]
            onExited: { root.scanning = false; devicesProc.running = true; }
        }

        function refresh()             { powerProc.running = true; }
        function togglePower(state)    { btCtl.command = ["bluetoothctl", "power", state ? "on" : "off"]; btCtl.running = true; }
        function toggleConnect(mac, c) { btCtl.command = ["bluetoothctl", c ? "disconnect" : "connect", mac]; btCtl.running = true; }
        function scan() { if (root.scanning) return; root.scanning = true; scanCtl.running = true; }

        Timer { interval: 5000; running: true; triggeredOnStart: true; repeat: true; onTriggered: root.refresh() }
    }
  '';

  quickshell.modules.BarBluetooth = ''
    import Quickshell
    import Quickshell.Io
    import QtQuick
    import "../Services"
    import "../Common"
    import "../Widgets"

    Item {
        id: root
        implicitHeight: 20
        implicitWidth:  icon.implicitWidth

        Text {
            id: icon
            anchors.centerIn: parent
            font.family: Glass.fontIcon
            font.pixelSize: 17
            font.variableAxes: BluetoothState.connectedCount > 0 ? Glass.iconActive : Glass.iconIdle
            color: BluetoothState.connectedCount > 0 ? Glass.text : Glass.muted
            text:  BluetoothState.connectedCount > 0 ? ""
                 : BluetoothState.scanning           ? ""
                 : BluetoothState.powered            ? ""
                 :                                     ""
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onClicked: {
                var opening = PopupState.owner !== root;
                PopupState.toggle(root);
                if (opening) BluetoothState.refresh();
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

                    PopupHeader {
                        width: parent.width
                        title: "Bluetooth"
                        on:    BluetoothState.powered
                        onToggled: BluetoothState.togglePower(!BluetoothState.powered)
                    }

                    Column {
                        width: parent.width; spacing: 2
                        visible: BluetoothState.powered

                        Repeater {
                            model: BluetoothState.devices
                            delegate: PopupRow {
                                required property var modelData
                                width:  col.width
                                glyph:  modelData.connected ? "" : ""
                                label:  modelData.name
                                active: modelData.connected
                                trailing: modelData.connected ? "" : ""
                                onActivated: {
                                    BluetoothState.toggleConnect(modelData.mac, modelData.connected);
                                    refreshTimer.restart();
                                }
                            }
                        }

                        PopupEmpty {
                            width: parent.width
                            visible: BluetoothState.devices.length === 0
                            label: "No devices"
                        }
                    }

                    PopupEmpty {
                        width: parent.width
                        visible: !BluetoothState.powered
                        label: "Bluetooth is off"
                    }

                    PopupAction {
                        width: parent.width
                        glyph: ""
                        label: BluetoothState.scanning ? "Scanning…" : "Scan for 5s"
                        enabled: !BluetoothState.scanning && BluetoothState.powered
                        onActivated: BluetoothState.scan()
                    }
                }
            }

            Timer { id: refreshTimer; interval: 2000; repeat: false; onTriggered: BluetoothState.refresh() }
        }
    }
  '';
}

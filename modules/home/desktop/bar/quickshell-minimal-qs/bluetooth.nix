{ ... }:

# BluetoothState service + BT bar widget + native quickshell popup, anchored
# under the bar icon and themed via Theme.* colors.

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
            id: powerProc
            running: false
            command: ["sh", "-c",
                "bluetoothctl show 2>/dev/null | grep -m1 'Powered:' | awk '{print $2}'"]
            stdout: SplitParser {
                onRead: data => {
                    root.powered = data.trim() === "yes";
                    if (root.powered) {
                        countProc.running = true;
                        devicesProc.running = true;
                    } else {
                        root.connectedCount = 0;
                        root.devices = [];
                    }
                }
            }
        }

        Process {
            id: countProc
            running: false
            command: ["sh", "-c", "bluetoothctl devices Connected 2>/dev/null | wc -l"]
            stdout: SplitParser {
                onRead: data => { root.connectedCount = parseInt(data.trim()) || 0; }
            }
        }

        Process {
            id: devicesProc
            running: false
            command: ["sh", "-c",
                "bluetoothctl devices 2>/dev/null | while read _ mac name; do "
                + "connected=$(bluetoothctl info \"$mac\" 2>/dev/null | grep -m1 'Connected:' | awk '{print $2}'); "
                + "echo \"$connected|$mac|$name\"; "
                + "done"]
            stdout: StdioCollector {
                onStreamFinished: {
                    var devs = [];
                    var lines = text.split("\n");
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i];
                        if (!line) continue;
                        var p = line.split("|");
                        if (p.length < 3) continue;
                        devs.push({
                            connected: p[0] === "yes",
                            mac: p[1],
                            name: p.slice(2).join("|"),
                        });
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
            id: scanCtl
            running: false
            command: ["bluetoothctl", "--timeout", "5", "scan", "on"]
            onExited: {
                root.scanning = false;
                devicesProc.running = true;
            }
        }

        function refresh() { powerProc.running = true; }
        function togglePower(state) {
            btCtl.command = ["bluetoothctl", "power", state ? "on" : "off"];
            btCtl.running = true;
        }
        function toggleConnect(mac, connected) {
            btCtl.command = ["bluetoothctl", connected ? "disconnect" : "connect", mac];
            btCtl.running = true;
        }
        function scan() {
            if (root.scanning) return;
            root.scanning = true;
            scanCtl.running = true;
        }

        Timer {
            interval: 5000
            running: true
            triggeredOnStart: true
            repeat: true
            onTriggered: root.refresh()
        }
    }
  '';

  quickshell.modules.BarBluetooth = ''
    import Quickshell
    import Quickshell.Io
    import QtQuick
    import "../Common"
    import "../Services"

    Rectangle {
        id: root
        color: Theme.surface
        radius: 5
        implicitHeight: 28
        implicitWidth: btText.implicitWidth + 14

        Text {
            id: btText
            anchors.centerIn: parent
            font.family:    "FiraMono Nerd Font"
            font.pixelSize: 19
            font.weight:    Font.Black
            color: BluetoothState.connectedCount > 0 ? Theme.selection
                 : BluetoothState.powered             ? Theme.fg
                 :                                      Theme.warning
            text: BluetoothState.connectedCount > 0
                ? "󰂱 " + BluetoothState.connectedCount
                : BluetoothState.powered ? "󰂯" : "󰂲"
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
            implicitHeight: popupBg.implicitHeight

            anchor.item: root
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom
            anchor.margins.top: 6

            Rectangle {
                id: popupBg
                anchors.fill: parent
                color: Theme.bg
                border.color: Theme.surface
                border.width: 1
                radius: 10
                implicitHeight: mainCol.implicitHeight + 16

                Column {
                    id: mainCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                    spacing: 6

                    Item {
                        width: parent.width
                        height: 28
                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            font.family: "FiraMono Nerd Font"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: Theme.fg
                            text: "󰂯  Bluetooth"
                        }
                        Rectangle {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            width: 40; height: 22; radius: 11
                            color: BluetoothState.powered ? Theme.selection : Theme.surface
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: Theme.bg
                                anchors.verticalCenter: parent.verticalCenter
                                x: BluetoothState.powered ? parent.width - width - 2 : 2
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: BluetoothState.togglePower(!BluetoothState.powered)
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.surface }

                    Column {
                        width: parent.width
                        spacing: 2
                        visible: BluetoothState.powered

                        Repeater {
                            model: BluetoothState.devices
                            delegate: Rectangle {
                                required property var modelData
                                width: mainCol.width
                                height: 28
                                color: devMouse.containsMouse ? Theme.surface : "transparent"
                                radius: 4

                                Row {
                                    anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                    spacing: 6
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.family: "FiraMono Nerd Font"
                                        font.pixelSize: 16
                                        color: modelData.connected ? Theme.selection : Theme.fg
                                        text: modelData.connected ? "󰂱" : "󰂯"
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.family: "FiraMono Nerd Font"
                                        font.pixelSize: 12
                                        color: modelData.connected ? Theme.selection : Theme.fg
                                        text: modelData.name
                                        width: parent.width - 40
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: devMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        BluetoothState.toggleConnect(modelData.mac, modelData.connected);
                                        refreshTimer.restart();
                                    }
                                }
                            }
                        }

                        Item {
                            visible: BluetoothState.devices.length === 0
                            width: parent.width
                            height: 24
                            Text {
                                anchors.centerIn: parent
                                font.family: "FiraMono Nerd Font"
                                font.pixelSize: 12
                                color: Theme.fg
                                text: "No devices"
                            }
                        }
                    }

                    Item {
                        visible: !BluetoothState.powered
                        width: parent.width
                        height: 24
                        Text {
                            anchors.centerIn: parent
                            font.family: "FiraMono Nerd Font"
                            font.pixelSize: 12
                            color: Theme.fg
                            text: "Bluetooth is off"
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 26
                        color: scanMouse.containsMouse ? Theme.selection : Theme.surface
                        radius: 4
                        Text {
                            anchors.centerIn: parent
                            font.family: "FiraMono Nerd Font"
                            font.pixelSize: 12
                            color: Theme.fg
                            text: BluetoothState.scanning ? "󰂰  Scanning…" : "󰂰  Scan (5s)"
                        }
                        MouseArea {
                            id: scanMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !BluetoothState.scanning && BluetoothState.powered
                            onClicked: BluetoothState.scan()
                        }
                    }
                }
            }

            Timer {
                id: refreshTimer
                interval: 2000
                repeat: false
                onTriggered: BluetoothState.refresh()
            }
        }
    }
  '';
}

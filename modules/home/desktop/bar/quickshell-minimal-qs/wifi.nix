{ ... }:

# NetworkState service + WiFi bar widget + native quickshell popup.
# Popup anchors to the bar icon so it lands right under it and uses Theme
# colors so it follows theme changes. No more GTK subprocess.

{
  quickshell.services.NetworkState = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        property bool   connected:   false
        property string ssid:        ""
        property int    signal:      0
        property bool   isEthernet:  false
        property bool   wifiEnabled: true
        property string wifiDev:     "wlan0"
        property var    networks:    []

        Process {
            id: typeProc
            running: false
            command: ["sh", "-c",
                "nmcli -t -f TYPE,STATE dev 2>/dev/null | grep ':connected' | head -1 | cut -d: -f1"]
            stdout: SplitParser {
                onRead: data => {
                    var t = data.trim();
                    root.isEthernet = (t === "ethernet");
                    root.connected  = (t === "wifi" || t === "ethernet");
                    if (t === "wifi") ssidProc.running = true;
                    else root.ssid = "";
                }
            }
        }

        Process {
            id: ssidProc
            running: false
            command: ["sh", "-c",
                "nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | grep '^yes:' | head -1"]
            stdout: SplitParser {
                onRead: data => {
                    var parts = data.trim().split(":");
                    if (parts.length >= 3) {
                        root.ssid   = parts.slice(1, parts.length - 1).join(":");
                        root.signal = parseInt(parts[parts.length - 1]) || 0;
                    }
                }
            }
        }

        Process {
            id: enabledProc
            running: false
            command: ["sh", "-c", "nmcli radio wifi 2>/dev/null"]
            stdout: SplitParser {
                onRead: data => { root.wifiEnabled = data.trim() === "enabled"; }
            }
        }

        Process {
            id: devProc
            running: false
            command: ["sh", "-c",
                "nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '$2==\"wifi\"{print $1;exit}'"]
            stdout: SplitParser {
                onRead: data => {
                    var d = data.trim();
                    if (d) root.wifiDev = d;
                }
            }
        }

        Process {
            id: scanProc
            running: false
            command: ["sh", "-c",
                "nmcli device wifi rescan 2>/dev/null; " +
                "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null"]
            stdout: StdioCollector {
                onStreamFinished: {
                    var lines = text.split("\n");
                    var nets = [];
                    var seen = ({});
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i];
                        if (!line || line.length === 0) continue;
                        var p = line.split(":");
                        if (p.length < 4) continue;
                        var inUse = p[0] === "*";
                        var sec = p[p.length - 1];
                        var sig = parseInt(p[p.length - 2]) || 0;
                        var ssid = p.slice(1, p.length - 2).join(":");
                        if (!ssid || seen[ssid]) continue;
                        seen[ssid] = true;
                        nets.push({inUse: inUse, ssid: ssid, signal: sig, sec: sec});
                    }
                    nets.sort(function(a, b) {
                        if (a.inUse !== b.inUse) return a.inUse ? -1 : 1;
                        return b.signal - a.signal;
                    });
                    root.networks = nets;
                }
            }
        }

        Process { id: wifiCtl; running: false; onExited: { root.refresh() } }

        function refresh() {
            typeProc.running = true;
            enabledProc.running = true;
            devProc.running = true;
        }
        function refreshNetworks() { scanProc.running = true; }
        function toggle(state) {
            wifiCtl.command = ["nmcli", "radio", "wifi", state ? "on" : "off"];
            wifiCtl.running = true;
        }
        function connect(ssid, pwd) {
            var args = ["nmcli", "device", "wifi", "connect", ssid];
            if (pwd) args = args.concat(["password", pwd]);
            wifiCtl.command = args;
            wifiCtl.running = true;
        }
        function disconnect() {
            wifiCtl.command = ["nmcli", "device", "disconnect", root.wifiDev];
            wifiCtl.running = true;
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

  quickshell.modules.BarWifi = ''
    import Quickshell
    import Quickshell.Io
    import QtQuick
    import QtQuick.Layouts
    import "../Common"
    import "../Services"

    Rectangle {
        id: root
        color: Theme.surface
        radius: 5
        implicitHeight: 28
        implicitWidth: layout.implicitWidth + 14

        RowLayout {
            id: layout
            anchors.centerIn: parent
            spacing: 4

            Text {
                font.family:    "FiraMono Nerd Font"
                font.pixelSize: 19
                font.weight:    Font.Black
                color: NetworkState.connected ? Theme.fg : Theme.warning
                text: {
                    if (NetworkState.isEthernet)    return "󰈀";
                    if (!NetworkState.connected)     return "󰤭";
                    var s = NetworkState.signal;
                    if (s >= 80) return "󰤨";
                    if (s >= 60) return "󰤥";
                    if (s >= 40) return "󰤢";
                    return "󰤟";
                }
            }

            Text {
                visible:        NetworkState.connected && !NetworkState.isEthernet && NetworkState.ssid !== ""
                font.family:    "FiraMono Nerd Font"
                font.pixelSize: 12
                color:          Theme.fg
                text:           NetworkState.ssid
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onClicked: {
                var opening = PopupState.owner !== root;
                PopupState.toggle(root);
                if (opening) NetworkState.refreshNetworks();
            }
        }

        PopupWindow {
            id: popup
            visible: PopupState.owner === root
            grabFocus: true
            onClosed: if (PopupState.owner === root) PopupState.close()
            color: "transparent"
            implicitWidth: 320
            implicitHeight: popupBg.implicitHeight

            anchor.item: root
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom
            anchor.margins.top: 6

            property string pwdSsid: ""

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
                            text: "󰤨  WiFi"
                        }
                        Rectangle {
                            id: sw
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            width: 40; height: 22; radius: 11
                            color: NetworkState.wifiEnabled ? Theme.selection : Theme.surface
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: Theme.bg
                                anchors.verticalCenter: parent.verticalCenter
                                x: NetworkState.wifiEnabled ? parent.width - width - 2 : 2
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NetworkState.toggle(!NetworkState.wifiEnabled)
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.surface }

                    Column {
                        width: parent.width
                        spacing: 2
                        visible: NetworkState.wifiEnabled

                        Repeater {
                            model: NetworkState.networks
                            delegate: Rectangle {
                                required property var modelData
                                width: mainCol.width
                                height: 28
                                color: netMouse.containsMouse ? Theme.surface : "transparent"
                                radius: 4

                                Row {
                                    anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                    spacing: 6
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.family: "FiraMono Nerd Font"
                                        font.pixelSize: 16
                                        color: modelData.inUse ? Theme.selection : Theme.fg
                                        text: {
                                            var s = modelData.signal;
                                            if (s >= 80) return "󰤨";
                                            if (s >= 60) return "󰤥";
                                            if (s >= 40) return "󰤢";
                                            if (s >= 20) return "󰤟";
                                            return "󰤯";
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.family: "FiraMono Nerd Font"
                                        font.pixelSize: 12
                                        color: modelData.inUse ? Theme.selection : Theme.fg
                                        text: modelData.ssid
                                        width: parent.width - 60
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.family: "FiraMono Nerd Font"
                                        font.pixelSize: 12
                                        color: Theme.fg
                                        visible: modelData.sec && modelData.sec !== "--"
                                        text: "󰌾"
                                    }
                                }

                                MouseArea {
                                    id: netMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.inUse) {
                                            NetworkState.disconnect();
                                        } else if (modelData.sec && modelData.sec !== "--") {
                                            popup.pwdSsid = modelData.ssid;
                                            pwdField.text = "";
                                            pwdField.forceActiveFocus();
                                        } else {
                                            NetworkState.connect(modelData.ssid, "");
                                        }
                                        pwdRefreshTimer.restart();
                                    }
                                }
                            }
                        }

                        Item {
                            visible: NetworkState.networks.length === 0
                            width: parent.width
                            height: 24
                            Text {
                                anchors.centerIn: parent
                                font.family: "FiraMono Nerd Font"
                                font.pixelSize: 12
                                color: Theme.fg
                                text: "Scanning…"
                            }
                        }
                    }

                    Item {
                        visible: !NetworkState.wifiEnabled
                        width: parent.width
                        height: 24
                        Text {
                            anchors.centerIn: parent
                            font.family: "FiraMono Nerd Font"
                            font.pixelSize: 12
                            color: Theme.fg
                            text: "WiFi is off"
                        }
                    }

                    Column {
                        visible: popup.pwdSsid !== ""
                        width: parent.width
                        spacing: 4
                        Rectangle { width: parent.width; height: 1; color: Theme.surface }
                        Text {
                            font.family: "FiraMono Nerd Font"
                            font.pixelSize: 12
                            color: Theme.fg
                            text: "Password for " + popup.pwdSsid
                        }
                        Rectangle {
                            width: parent.width
                            height: 26
                            color: Theme.surface
                            radius: 4
                            TextInput {
                                id: pwdField
                                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: "FiraMono Nerd Font"
                                font.pixelSize: 12
                                color: Theme.fg
                                echoMode: TextInput.Password
                                focus: popup.pwdSsid !== ""
                                onAccepted: {
                                    if (text.length > 0) {
                                        NetworkState.connect(popup.pwdSsid, text);
                                        popup.pwdSsid = "";
                                        text = "";
                                        pwdRefreshTimer.restart();
                                    }
                                }
                                Keys.onEscapePressed: { popup.pwdSsid = ""; text = ""; }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 26
                        color: rescanMouse.containsMouse ? Theme.selection : Theme.surface
                        radius: 4
                        Text {
                            anchors.centerIn: parent
                            font.family: "FiraMono Nerd Font"
                            font.pixelSize: 12
                            color: Theme.fg
                            text: "󰑐  Rescan"
                        }
                        MouseArea {
                            id: rescanMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NetworkState.refreshNetworks()
                        }
                    }
                }
            }

            Timer {
                id: pwdRefreshTimer
                interval: 2000
                repeat: false
                onTriggered: NetworkState.refreshNetworks()
            }
        }
    }
  '';
}

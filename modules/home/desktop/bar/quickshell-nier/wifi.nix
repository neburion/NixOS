{ ... }:

# NetworkState service + sepia WiFi widget + popup (same logic, fixed sepia colors).

{
  quickshell.services.NetworkState = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        property bool   connected:        false
        property string ssid:             ""
        property int    signal:           0
        property bool   isEthernet:       false
        property bool   wifiEnabled:      true
        property string wifiDev:          "wlan0"
        property var    networks:         []
        property var    savedConnections: []

        Process {
            id: typeProc; running: false
            command: ["sh", "-c", "nmcli -t -f TYPE,STATE dev 2>/dev/null | grep ':connected' | head -1 | cut -d: -f1"]
            stdout: SplitParser {
                onRead: data => {
                    var t = data.trim();
                    root.isEthernet = (t === "ethernet");
                    root.connected  = (t === "wifi" || t === "ethernet");
                    if (t === "wifi") ssidProc.running = true; else root.ssid = "";
                }
            }
        }

        Process {
            id: ssidProc; running: false
            command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | grep '^yes:' | head -1"]
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
            id: enabledProc; running: false
            command: ["sh", "-c", "nmcli radio wifi 2>/dev/null"]
            stdout: SplitParser { onRead: data => { root.wifiEnabled = data.trim() === "enabled"; } }
        }

        Process {
            id: devProc; running: false
            command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '$2==\"wifi\"{print $1;exit}'"]
            stdout: SplitParser { onRead: data => { var d = data.trim(); if (d) root.wifiDev = d; } }
        }

        Process {
            id: scanProc; running: false
            command: ["sh", "-c",
                "nmcli device wifi rescan 2>/dev/null; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null"]
            stdout: StdioCollector {
                onStreamFinished: {
                    var lines = text.split("\n"); var nets = []; var seen = ({});
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i]; if (!line) continue;
                        var p = line.split(":"); if (p.length < 4) continue;
                        var inUse = p[0] === "*";
                        var sec = p[p.length - 1]; var sig = parseInt(p[p.length - 2]) || 0;
                        var ssid = p.slice(1, p.length - 2).join(":");
                        if (!ssid) continue;
                        if (seen[ssid] !== undefined) {
                            if (inUse) nets[seen[ssid]].inUse = true;
                            continue;
                        }
                        seen[ssid] = nets.length;
                        nets.push({ inUse: inUse, ssid: ssid, signal: sig, sec: sec });
                    }
                    nets.sort(function(a, b) { if (a.inUse !== b.inUse) return a.inUse ? -1 : 1; return b.signal - a.signal; });
                    root.networks = nets;
                }
            }
        }

        Process {
            id: savedProc; running: false
            command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep ':802-11-wireless' | cut -d: -f1"]
            stdout: StdioCollector {
                onStreamFinished: {
                    root.savedConnections = text.split("\n").map(function(l) { return l.trim(); }).filter(Boolean);
                }
            }
        }

        Process { id: wifiCtl; running: false; onExited: { root.refresh() } }

        function refresh()          { typeProc.running = true; enabledProc.running = true; devProc.running = true; }
        function refreshNetworks()  { savedProc.running = true; scanProc.running = true; }
        function toggle(state)      { wifiCtl.command = ["nmcli", "radio", "wifi", state ? "on" : "off"]; wifiCtl.running = true; }
        function connect(ssid, pwd) {
            var args = ["nmcli", "device", "wifi", "connect", ssid];
            if (pwd) args = args.concat(["password", pwd]);
            wifiCtl.command = args; wifiCtl.running = true;
        }
        function disconnect() { wifiCtl.command = ["nmcli", "device", "disconnect", root.wifiDev]; wifiCtl.running = true; }

        Timer { interval: 5000; running: true; triggeredOnStart: true; repeat: true; onTriggered: root.refresh() }
    }
  '';

  quickshell.modules.BarWifi = ''
    import Quickshell
    import Quickshell.Io
    import QtQuick
    import QtQuick.Layouts
    import "../Services"
    import "../Common"

    Item {
        id: root
        implicitHeight: parent.height
        implicitWidth:  wifiRow.implicitWidth

        RowLayout {
            id: wifiRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                font.family: "FiraMono Nerd Font"
                font.pixelSize: 13
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
                visible:       NetworkState.connected && !NetworkState.isEthernet && NetworkState.ssid !== ""
                font.family: "Share Tech Mono"
                font.pixelSize: 12
                color:  Theme.fg
                text:   NetworkState.ssid
            }
        }

        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
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
                border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3)
                border.width: 1
                radius: 4
                implicitHeight: mainCol.implicitHeight + 16

                Column {
                    id: mainCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                    spacing: 6

                    Item {
                        width: parent.width; height: 28
                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            font.family: "FiraMono Nerd Font"; font.pixelSize: 13; font.weight: Font.Bold
                            color: Theme.fg; text: "󰤨  NETWORK"
                        }
                        Rectangle {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            width: 44; height: 18; radius: 0
                            color: "transparent"
                            border.color: NetworkState.wifiEnabled ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.38)
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                font.family: "Share Tech Mono"; font.pixelSize: 10
                                color: NetworkState.wifiEnabled ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.38)
                                text: NetworkState.wifiEnabled ? "ON" : "OFF"
                                font.letterSpacing: 2
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: NetworkState.toggle(!NetworkState.wifiEnabled) }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.surface }

                    Column {
                        width: parent.width; spacing: 2; visible: NetworkState.wifiEnabled
                        Repeater {
                            model: NetworkState.networks
                            delegate: Rectangle {
                                required property var modelData
                                width: mainCol.width; height: 28
                                color: netMouse.containsMouse ? Theme.surface : "transparent"; radius: 2
                                Row {
                                    anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                    spacing: 6
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.family: "FiraMono Nerd Font"; font.pixelSize: 14
                                        color: modelData.inUse ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
                                        text: modelData.signal >= 80 ? "󰤨" : modelData.signal >= 60 ? "󰤥" : modelData.signal >= 40 ? "󰤢" : modelData.signal >= 20 ? "󰤟" : "󰤯"
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.family: "Share Tech Mono"; font.pixelSize: 12
                                        color: modelData.inUse ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
                                        text: modelData.ssid; width: parent.width - 60; elide: Text.ElideRight
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.family: "FiraMono Nerd Font"; font.pixelSize: 12
                                        visible: modelData.inUse || (modelData.sec && modelData.sec !== "--")
                                        color: modelData.inUse ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
                                        text: modelData.inUse ? "󰸞" : "󰌾"
                                    }
                                }
                                MouseArea { id: netMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.inUse) {
                                            NetworkState.disconnect();
                                        } else if (modelData.sec && modelData.sec !== "--"
                                                   && NetworkState.savedConnections.indexOf(modelData.ssid) < 0) {
                                            popup.pwdSsid = modelData.ssid; pwdField.text = ""; pwdField.forceActiveFocus();
                                        } else {
                                            NetworkState.connect(modelData.ssid, "");
                                        }
                                        pwdRefreshTimer.restart();
                                    } }
                            }
                        }
                        Item { visible: NetworkState.networks.length === 0; width: parent.width; height: 24
                            Text { anchors.centerIn: parent; font.family: "Share Tech Mono"; font.pixelSize: 12; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65); text: "SCANNING…" } }
                    }

                    Item { visible: !NetworkState.wifiEnabled; width: parent.width; height: 24
                        Text { anchors.centerIn: parent; font.family: "Share Tech Mono"; font.pixelSize: 12; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65); text: "WIFI OFF" } }

                    Column {
                        visible: popup.pwdSsid !== ""; width: parent.width; spacing: 4
                        Rectangle { width: parent.width; height: 1; color: Theme.surface }
                        Text { font.family: "Share Tech Mono"; font.pixelSize: 12; color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65); text: "PASSWORD : " + popup.pwdSsid }
                        Rectangle {
                            width: parent.width; height: 26; color: Theme.surface; radius: 2
                            TextInput {
                                id: pwdField
                                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: "Share Tech Mono"; font.pixelSize: 12
                                color: Theme.fg; echoMode: TextInput.Password; focus: popup.pwdSsid !== ""
                                onAccepted: { if (text.length > 0) { NetworkState.connect(popup.pwdSsid, text); popup.pwdSsid = ""; text = ""; pwdRefreshTimer.restart(); } }
                                Keys.onEscapePressed: { popup.pwdSsid = ""; text = ""; }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width; height: 26; radius: 2
                        color: rescanMouse.containsMouse ? Theme.surface : "transparent"
                        Text { anchors.centerIn: parent; font.family: "Share Tech Mono"; font.pixelSize: 12; color: Theme.fg; text: "RESCAN" }
                        MouseArea { id: rescanMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NetworkState.refreshNetworks() }
                    }
                }
            }

            Timer { id: pwdRefreshTimer; interval: 2000; repeat: false; onTriggered: NetworkState.refreshNetworks() }
        }
    }
  '';
}

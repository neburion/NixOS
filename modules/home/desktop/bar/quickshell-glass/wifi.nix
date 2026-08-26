{ ... }:

# NetworkState service (verbatim from clean) + glass Wi-Fi indicator and popup.

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
    import "../Services"
    import "../Common"
    import "../Widgets"

    Item {
        id: root
        implicitHeight: 20
        implicitWidth:  Math.max(track.implicitWidth, strength.implicitWidth)

        readonly property bool wifiMode: !NetworkState.isEthernet && NetworkState.wifiEnabled

        // Material's wifi_1_bar / wifi_2_bar are not a dimmed full icon — they
        // omit the upper arcs entirely, so a weak signal looked like a broken
        // glyph with its top missing. They ARE geometric subsets of `wifi` on
        // the same grid though, so drawing the full cone faintly underneath
        // puts the unreached arcs back as an outline.
        Text {
            id: track
            anchors.centerIn: parent
            visible: root.wifiMode
            font.family: Glass.fontIcon
            font.pixelSize: 17
            font.variableAxes: Glass.iconIdle
            color: Glass.faint
            text:  ""
        }

        Text {
            id: strength
            anchors.centerIn: parent
            font.family: Glass.fontIcon
            font.pixelSize: 17
            font.variableAxes: NetworkState.connected ? Glass.iconActive : Glass.iconIdle
            color: NetworkState.connected ? Glass.text : Glass.muted

            text: {
                if (NetworkState.isEthernet)    return "";
                if (!NetworkState.wifiEnabled)  return "";
                // Radio on but no link: the faint cone behind is the whole
                // story, so draw nothing over it.
                if (!NetworkState.connected)    return "";
                if (NetworkState.signal >= 70)  return "";
                if (NetworkState.signal >= 40)  return "";
                return "";
            }

            Behavior on color { ColorAnimation { duration: 200 } }
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
            implicitWidth: 300
            implicitHeight: shell.implicitHeight

            anchor.item: root
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom
            anchor.margins.top: 10

            property string pwdSsid: ""

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
                        title: "Network"
                        on:    NetworkState.wifiEnabled
                        onToggled: NetworkState.toggle(!NetworkState.wifiEnabled)
                    }

                    Column {
                        width: parent.width; spacing: 2
                        visible: NetworkState.wifiEnabled

                        Repeater {
                            model: NetworkState.networks
                            delegate: PopupRow {
                                required property var modelData
                                width: col.width
                                track: ""
                                glyph: modelData.signal >= 70 ? ""
                                     : modelData.signal >= 40 ? ""
                                     :                          ""
                                label:  modelData.ssid
                                active: modelData.inUse
                                trailing: modelData.inUse ? ""
                                        : (modelData.sec && modelData.sec !== "--") ? "" : ""
                                onActivated: {
                                    if (modelData.inUse) {
                                        NetworkState.disconnect();
                                    } else if (modelData.sec && modelData.sec !== "--"
                                               && NetworkState.savedConnections.indexOf(modelData.ssid) < 0) {
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

                        PopupEmpty {
                            width: parent.width
                            visible: NetworkState.networks.length === 0
                            label: "Scanning…"
                        }
                    }

                    PopupEmpty {
                        width: parent.width
                        visible: !NetworkState.wifiEnabled
                        label: "Wi-Fi is off"
                    }

                    Column {
                        visible: popup.pwdSsid !== ""
                        width: parent.width
                        spacing: 5

                        Text {
                            font.family: Glass.fontUi; font.pixelSize: 12
                            color: Glass.muted
                            text:  "Password for " + popup.pwdSsid
                        }
                        Rectangle {
                            width: parent.width; height: 30; radius: 9
                            color: Qt.rgba(1, 1, 1, 0.07)
                            border.width: 1
                            border.color: Glass.stroke
                            TextInput {
                                id: pwdField
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: Glass.fontUi; font.pixelSize: 13
                                color: Glass.text
                                echoMode: TextInput.Password
                                focus: popup.pwdSsid !== ""
                                onAccepted: {
                                    if (text.length > 0) {
                                        NetworkState.connect(popup.pwdSsid, text);
                                        popup.pwdSsid = ""; text = "";
                                        pwdRefreshTimer.restart();
                                    }
                                }
                                Keys.onEscapePressed: { popup.pwdSsid = ""; text = ""; }
                            }
                        }
                    }

                    PopupAction {
                        width: parent.width
                        glyph: ""
                        label: "Rescan"
                        onActivated: NetworkState.refreshNetworks()
                    }
                }
            }

            Timer { id: pwdRefreshTimer; interval: 2000; repeat: false; onTriggered: NetworkState.refreshNetworks() }
        }
    }
  '';
}

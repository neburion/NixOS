{ ... }:

# Active window title — reads HyprlandIpc.focusedClient set in workspaces.nix.

{
  quickshell.modules.BarWindowTitle = ''
    import QtQuick
    import "../Services"
    import "../Common"

    Item {
        implicitHeight: parent.height
        implicitWidth:  Math.min(titleText.implicitWidth, 280)
        clip: true

        Text {
            id: titleText
            anchors.verticalCenter: parent.verticalCenter
            font.family: "Share Tech Mono"
            font.pixelSize: 12
            color:   Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
            text:    HyprlandIpc.focusedClient ? HyprlandIpc.focusedClient.title : ""
            elide:   Text.ElideRight
            width:   Math.min(implicitWidth, 280)
        }
    }
  '';
}

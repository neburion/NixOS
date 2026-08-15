{ ... }:

{
  quickshell.widgets.Capsule = ''
    import QtQuick
    import "../Common"

    Rectangle {
        id: root
        color: Theme.surface
        radius: 5
        implicitHeight: content.implicitHeight
        implicitWidth: content.implicitWidth

        default property alias data: content.data
        property alias contentItem: content

        Item {
            id: content
            anchors.fill: parent
        }
    }
  '';
}

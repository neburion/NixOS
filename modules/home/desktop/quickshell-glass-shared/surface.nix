{ ... }:

# Widgets/GlassSurface.qml — the one translucent panel primitive.
#
# Fill + 1px stroke + an inset top highlight. The highlight is what reads as
# glass; without it a translucent rectangle just looks like a dimmed one. The
# blur itself is the compositor's (see wm/hyprland-glass/layer-rules.nix) —
# this only produces a surface worth blurring.
#
# No `default property alias` wrapping an inner Item: in QML that alias also
# captures the component's own declared children, so the inner Item would be
# assigned into itself. The specular strip is simply declared first, which
# puts it behind anything the caller adds.

{
  quickshell.widgets.GlassSurface = ''
    import QtQuick
    import "../Common"

    Rectangle {
        id: root

        property bool strong: false

        color:        root.strong ? Glass.panelStrong : Glass.panel
        radius:       Glass.popupRadius
        border.width: 1
        border.color: Glass.stroke
        antialiasing: true

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.margins: 1
            height:  1
            color:   Glass.highlight
            opacity: 0.9
        }
    }
  '';
}

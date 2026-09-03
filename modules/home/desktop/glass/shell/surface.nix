{ ... }:

# Widgets/GlassSurface.qml — the one translucent panel primitive.
#
# Fill plus a 1px stroke, and nothing else.
#
# There was a specular strip along the top edge here: a 1px Rectangle at 20%
# white, meant to read as light catching the lip of the panel. It didn't. A
# straight strip inside a rounded rectangle runs flat through both top corners
# instead of following them, so on every surface — bar, launcher, popups,
# notifications, OSD, picker — it read as a hairline drawn across the box
# rather than as an edge. The border alone already describes the edge, and
# describes it on all four sides.

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
    }
  '';
}

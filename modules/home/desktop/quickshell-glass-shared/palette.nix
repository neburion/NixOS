{ ... }:

# Common/Glass.qml — the whole palette, as literals.
#
# Deliberately NOT reactive: no ThemeState binding, no palette table, no
# switching. The single value that moves at runtime is the accent, and that
# lives in Services/WallpaperState.qml because it is per-monitor.

{
  quickshell.commons.Glass = ''
    pragma Singleton
    import Quickshell
    import QtQuick

    Singleton {
        id: root

        // ---- surfaces ----------------------------------------------------
        readonly property color ink:         "#05070B"
        readonly property color panel:       Qt.rgba(0.071, 0.082, 0.110, 0.44)
        // Menus, not chrome. These carry text you have to read against
        // whatever the wallpaper happens to be, so they trade transparency
        // for legibility — the blur still shows through at this alpha.
        readonly property color panelStrong: Qt.rgba(0.071, 0.082, 0.110, 0.88)
        readonly property color stroke:      Qt.rgba(1, 1, 1, 0.11)
        readonly property color hover:       Qt.rgba(1, 1, 1, 0.10)

        // ---- text --------------------------------------------------------
        readonly property color text:     "#EDF0F5"
        readonly property color muted:    Qt.rgba(0.929, 0.941, 0.961, 0.56)
        readonly property color faint:    Qt.rgba(0.929, 0.941, 0.961, 0.28)
        readonly property color critical: "#FF8A80"

        // Fallback accent, used when a monitor has no wallpaper-derived hue.
        // Kept here rather than imported from Services to avoid a
        // Common -> Services -> Common import loop.
        readonly property color accentFallback: "#EDF0F5"

        // ---- type --------------------------------------------------------
        readonly property string fontUi:   "Inter"
        readonly property string fontMono: "Geist Mono"
        readonly property string fontIcon: "Material Symbols Rounded"

        readonly property var tnum: ({ "tnum": 1 })

        // Material Symbols variable axes. Active state animates FILL 0 -> 1.
        function icon(fill, weight) {
            return { "FILL": fill, "wght": weight, "GRAD": 0, "opsz": 24 };
        }
        readonly property var iconIdle:   root.icon(0.0, 300)
        readonly property var iconActive: root.icon(1.0, 350)

        // ---- metrics -----------------------------------------------------
        readonly property int barZone:    50   // exclusive zone, full width
        readonly property int barHeight:  34   // the visible panel
        readonly property int barMargin:  12   // left/right inset
        readonly property int barTop:     10   // gap above the panel
        readonly property int barRadius:  12

        readonly property int popupRadius:    14
        readonly property int launcherWidth:  520
        readonly property int launcherRadius: 18
        readonly property int rowHeight:      40
        readonly property int rowRadius:      11
    }
  '';
}

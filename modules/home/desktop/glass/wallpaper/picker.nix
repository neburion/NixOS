{ ... }:

# Wallpaper picker — per monitor, filtered by orientation.
#
# Two differences from the clean picker, both consequences of the library
# being ~/Media/Wallpapers/<Orientation>/<Category>/ rather than per-theme
# folders:
#
#   1. It applies to ONE monitor — the focused one — instead of every output.
#      That is what makes the wallpaper (and therefore the accent) per-screen.
#   2. It scans by orientation, not by theme. Category is a filing system, so
#      the scan is recursive and every category lands in one flat carousel.
#      Orientation is the part the shell can act on: a portrait monitor has no
#      use for a 3840x2160 landscape image.
#
# `orientation` is a binding on focusedMonitor.transform, so rotating a screen
# ($mod + backslash) re-scans with no extra wiring.

{
  quickshell.modules.WallpaperPicker = ''
    import Quickshell
    import Quickshell.Wayland
    import Quickshell.Widgets
    import Quickshell.Io
    import QtQuick
    import "../Services"
    import "../Common"
    import "../Widgets"

    PanelWindow {
        id: root
        visible: false
        color: "transparent"
        anchors { top: true; left: true; right: true; bottom: true }

        WlrLayershell.namespace: "quickshell:wallpaper"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        readonly property string monName:     HyprlandIpc.focusedName
        readonly property string orientation: HyprlandIpc.focusedOrientation

        // Render on the screen it is going to dress. Without this the picker
        // lands on whichever screen quickshell picked first, so you could be
        // choosing a wallpaper for HDMI-A-1 while looking at DP-1.
        screen: HyprlandIpc.focusedScreen

        readonly property color accent: WallpaperState.accentFor(root.monName)
        readonly property string activePath: WallpaperState.pathFor(root.monName)

        function isVideo(path) {
            const ext = path.split('.').pop().toLowerCase();
            return ["mp4", "mkv", "webm", "avi", "mov", "gif"].indexOf(ext) >= 0;
        }

        function apply(path) {
            WallpaperState.apply(root.monName, path);
            root.visible = false;
        }

        ListModel { id: wallpapers }

        Process {
            id: scanner
            running: false
            command: ["sh", "-c",
                "find \"$1/" + root.orientation + "\" -type f \\( " +
                "-iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' " +
                "-o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' " +
                "-o -iname '*.avi' -o -iname '*.mov'" +
                " \\) 2>/dev/null | sort",
                "sh", Quickshell.env("HOME") + "/Media/Wallpapers"]
            stdout: SplitParser {
                onRead: data => {
                    const p = data.trim();
                    if (p.length === 0) return;
                    wallpapers.append({ path: p });
                    if (p === root.activePath) {
                        const idx = wallpapers.count - 1;
                        carousel.currentIndex = idx;
                        carousel.positionViewAtIndex(idx, ListView.Center);
                    }
                }
            }
        }

        IpcHandler {
            target: "wallpaperPicker"
            function toggle() {
                if (!root.visible) { wallpapers.clear(); scanner.running = true; }
                root.visible = !root.visible;
                if (root.visible) carousel.forceActiveFocus();
            }
            function hide() { root.visible = false; }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Glass.ink.r, Glass.ink.g, Glass.ink.b, 0.72)
            MouseArea { anchors.fill: parent; onClicked: root.visible = false }
        }

        // ---- header: which screen you are dressing, and with what ----
        GlassSurface {
            id: header
            anchors { top: parent.top; topMargin: 26; horizontalCenter: parent.horizontalCenter }
            width:  headerRow.implicitWidth + 36
            height: 40
            radius: 20

            Row {
                id: headerRow
                anchors.centerIn: parent
                spacing: 11

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Glass.fontIcon
                    font.pixelSize: 17
                    font.variableAxes: Glass.iconIdle
                    color: root.accent
                    text: ""
                    rotation: root.orientation === "Vertical" ? 90 : 0
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Glass.fontUi
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    font.letterSpacing: -0.13
                    color: Glass.text
                    text: root.monName
                }

                Rectangle {
                    width: 1; height: 14
                    color: Qt.rgba(1, 1, 1, 0.14)
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Glass.fontUi
                    font.pixelSize: 12
                    color: Glass.muted
                    text: root.orientation.toLowerCase() + " · " + wallpapers.count
                          + (wallpapers.count === 1 ? " image" : " images")
                }
            }
        }

        // ---- carousel ----
        ListView {
            id: carousel
            anchors {
                top: header.bottom; topMargin: 26
                left: parent.left; right: parent.right
                bottom: footer.top; bottomMargin: 22
            }
            orientation: ListView.Horizontal
            snapMode: ListView.SnapToItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width - cellWidth) / 2
            preferredHighlightEnd:   (width + cellWidth) / 2
            model: wallpapers
            focus: true
            clip: true
            highlightMoveDuration: 140

            // Portrait images want a tall frame; landscape a wide one. Sizing
            // the cell from the orientation keeps the carousel from letterboxing
            // half the library.
            readonly property bool tall: root.orientation === "Vertical"
            readonly property int cellWidth:  tall ? 620 : 1000
            readonly property int frameW:     tall ? 430 : 900
            readonly property int frameH:     tall ? Math.min(height, 760) : Math.min(height, 560)

            MouseArea { anchors.fill: parent; onClicked: {} }

            Keys.onEscapePressed: root.visible = false
            Keys.onReturnPressed: {
                if (currentIndex >= 0 && currentIndex < count)
                    root.apply(model.get(currentIndex).path);
            }
            Keys.onLeftPressed:  decrementCurrentIndex()
            Keys.onRightPressed: incrementCurrentIndex()
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_H)      { decrementCurrentIndex(); event.accepted = true; }
                else if (event.key === Qt.Key_L) { incrementCurrentIndex(); event.accepted = true; }
            }

            delegate: Item {
                id: cell
                required property int index
                required property string path

                width:  carousel.cellWidth
                height: carousel.height

                readonly property bool isCurrent: ListView.isCurrentItem
                readonly property bool isVid:     root.isVideo(cell.path)
                readonly property bool isActive:  root.activePath === cell.path

                // ClippingRectangle, not Rectangle: QtQuick's `clip` clips to
                // the bounding rect, NOT to the corner radius, so a plain
                // Rectangle left the image's square corners poking out past the
                // rounded border. This one clips to the actual shape, and
                // insets content by the border width itself — which also stops
                // the preview shifting a pixel when the active frame's border
                // goes 1 -> 2.
                ClippingRectangle {
                    id: frame
                    anchors.centerIn: parent
                    width:   cell.isCurrent ? carousel.frameW : Math.round(carousel.frameW * 0.4)
                    height:  cell.isCurrent ? carousel.frameH : Math.round(carousel.frameH * 0.4)
                    opacity: cell.isCurrent ? 1.0 : 0.38
                    radius:  14
                    color:   Glass.ink
                    antialiasing: true

                    border.width: cell.isActive ? 2 : 1
                    border.color: cell.isActive  ? root.accent
                                : cell.isCurrent ? Qt.rgba(1, 1, 1, 0.22)
                                :                  "transparent"

                    Behavior on width   { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    Behavior on height  { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 130 } }

                    Image {
                        anchors.fill: parent
                        visible: !cell.isVid
                        source: cell.isVid ? "" : "file://" + cell.path
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    // Animated files are not previewed — decoding every gif in
                    // the carousel to show one frame is not worth the stutter.
                    Item {
                        anchors.fill: parent
                        visible: cell.isVid
                        Text {
                            anchors.centerIn: parent
                            font.family: Glass.fontIcon
                            font.pixelSize: 44
                            font.variableAxes: Glass.iconIdle
                            color: Glass.faint
                            text: ""
                        }
                    }

                    Rectangle {
                        visible: cell.isCurrent
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 34
                        color: Qt.rgba(Glass.ink.r, Glass.ink.g, Glass.ink.b, 0.72)

                        Text {
                            anchors {
                                verticalCenter: parent.verticalCenter
                                left: parent.left; right: parent.right
                                leftMargin: 14; rightMargin: 14
                            }
                            horizontalAlignment: Text.AlignHCenter
                            font.family: Glass.fontUi
                            font.pixelSize: 12
                            color: Glass.text
                            elide: Text.ElideMiddle
                            // Category is worth showing here even though it does
                            // not filter anything — it is how you think about
                            // the file when you are looking for it.
                            text: {
                                const parts = cell.path.split("/");
                                const name  = parts.pop();
                                const cat   = parts.pop();
                                return cat + "  ·  " + name;
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (cell.isCurrent) root.apply(cell.path);
                        else carousel.currentIndex = cell.index;
                    }
                }
            }
        }

        // ---- empty state ----
        Text {
            anchors.centerIn: parent
            visible: wallpapers.count === 0
            font.family: Glass.fontUi
            font.pixelSize: 14
            color: Glass.muted
            text: "Nothing in ~/Media/Wallpapers/" + root.orientation
        }

        // ---- footer ----
        GlassSurface {
            id: footer
            anchors { bottom: parent.bottom; bottomMargin: 26; horizontalCenter: parent.horizontalCenter }
            width:  footerText.implicitWidth + 34
            height: 32
            radius: 16

            Text {
                id: footerText
                anchors.centerIn: parent
                font.family: Glass.fontMono
                font.pixelSize: 10
                font.letterSpacing: 1.1
                color: Glass.faint
                text: "← →  BROWSE      ENTER  APPLY TO " + root.monName.toUpperCase() + "      ESC  CLOSE"
            }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "WallpaperPicker {}" ];
}

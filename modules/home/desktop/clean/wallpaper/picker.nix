{ pkgs, ... }:

# WallpaperState service + carousel picker overlay.
# Center = selected, left/right = previews. ← → navigate, Enter apply, Esc close.

{
  home.packages = with pkgs; [ awww mpvpaper ];

  quickshell.services.WallpaperState = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        property string currentPath: ""

        readonly property string _statePath:
            `''${Quickshell.env("HOME")}/.local/state/quickshell/wallpaper`

        FileView {
            id: stateFile
            path: root._statePath
            watchChanges: true
            onFileChanged: reload()
            onLoaded: {
                var p = text().trim();
                if (p.length > 0 && p !== root.currentPath)
                    root.currentPath = p;
            }
        }

        Process { id: writer; running: false }

        function setWallpaper(path) {
            root.currentPath = path;
            writer.command = ["sh", "-c", "echo \"$1\" > \"$2\"",
                              "sh", path, root._statePath];
            writer.running = true;
        }
    }
  '';

  quickshell.modules.WallpaperPicker = ''
    import Quickshell
    import Quickshell.Wayland
    import Quickshell.Io
    import QtQuick
    import "../Services"
    import "../Common"

    PanelWindow {
        id: root
        visible: false
        color: "#dd000000"
        anchors { top: true; left: true; right: true; bottom: true }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        IpcHandler {
            target: "wallpaperPicker"
            function toggle() {
                if (!root.visible) { wallpapers.clear(); scanner.running = true; }
                root.visible = !root.visible;
                if (root.visible) carousel.forceActiveFocus();
            }
        }

        function isVideo(path) {
            var ext = path.split('.').pop().toLowerCase();
            return ["mp4", "mkv", "webm", "avi", "mov", "gif"].indexOf(ext) >= 0;
        }

        function applyWallpaper(path) {
            WallpaperState.setWallpaper(path);
            var cmd = root.isVideo(path)
                ? "pkill mpvpaper 2>/dev/null; mpvpaper '*' \"$1\" --mpv-options 'loop-file=inf' &"
                : "pkill mpvpaper 2>/dev/null; awww img \"$1\" --transition-type fade";
            applier.command = ["sh", "-c", cmd, "sh", path];
            applier.running = true;
            root.visible = false;
        }

        ListModel { id: wallpapers }

        Process {
            id: scanner
            running: false
            command: ["sh", "-c",
                "find \"" + Quickshell.env("HOME") +
                "/Media/Wallpapers/" + Theme.wallpaperDir +
                "\" -maxdepth 1 -type f \\( " +
                "-name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' " +
                "-o -name '*.mp4' -o -name '*.mkv' -o -name '*.webm' " +
                "-o -name '*.avi' -o -name '*.mov' -o -name '*.gif'" +
                " \\) 2>/dev/null | sort"]
            stdout: SplitParser {
                onRead: data => {
                    var p = data.trim();
                    if (p.length > 0) {
                        wallpapers.append({ path: p });
                        if (p === WallpaperState.currentPath) {
                            var idx = wallpapers.count - 1;
                            carousel.currentIndex = idx;
                            carousel.positionViewAtIndex(idx, ListView.Center);
                        }
                    }
                }
            }
        }

        Process { id: applier; running: false }

        MouseArea { anchors.fill: parent; onClicked: root.visible = false }

        // Header
        Item {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 24 }
            height: 24
            Text {
                anchors.centerIn: parent
                text: "WALLPAPER SELECT  ·  " + Theme.wallpaperDir.toUpperCase()
                font.family: "Share Tech Mono"; font.pixelSize: 12
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.75)
                font.letterSpacing: 2
            }
            Text {
                anchors { right: parent.right; rightMargin: 40; verticalCenter: parent.verticalCenter }
                text: wallpapers.count + " ENTRIES"
                font.family: "Share Tech Mono"; font.pixelSize: 11
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.55)
                font.letterSpacing: 1
            }
        }

        // Carousel
        ListView {
            id: carousel
            anchors { top: header.bottom; topMargin: 20; left: parent.left; right: parent.right; bottom: footer.top; bottomMargin: 20 }
            orientation: ListView.Horizontal
            snapMode: ListView.SnapToItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width - 1000) / 2
            preferredHighlightEnd:   (width + 1000) / 2
            model: wallpapers
            focus: true
            clip: true
            highlightMoveDuration: 100
            MouseArea { anchors.fill: parent; onClicked: {} }

            Keys.onEscapePressed: root.visible = false
            Keys.onReturnPressed: {
                if (currentIndex >= 0 && currentIndex < count)
                    root.applyWallpaper(model.get(currentIndex).path);
            }
            Keys.onLeftPressed:  decrementCurrentIndex()
            Keys.onRightPressed: incrementCurrentIndex()
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_H) { decrementCurrentIndex(); event.accepted = true; }
                else if (event.key === Qt.Key_L) { incrementCurrentIndex(); event.accepted = true; }
            }

            delegate: Item {
                id: cell
                width: 1000
                height: carousel.height

                property bool isCurrent: ListView.isCurrentItem
                property bool isVid:     root.isVideo(model.path)
                property bool isActive:  WallpaperState.currentPath === model.path

                Rectangle {
                    id: frame
                    anchors.centerIn: parent
                    width:   cell.isCurrent ? 960 : 360
                    height:  cell.isCurrent ? 600 : 225
                    opacity: cell.isCurrent ? 1.0 : 0.4
                    color:   Theme.bg
                    border.color: cell.isActive ? Theme.fg
                                : cell.isCurrent ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.5)
                                : "transparent"
                    border.width: cell.isActive ? 2 : 1

                    Behavior on width   { NumberAnimation { duration: 60 } }
                    Behavior on height  { NumberAnimation { duration: 60 } }
                    Behavior on opacity { NumberAnimation { duration: 60 } }

                    Image {
                        anchors.fill: parent
                        anchors.margins: frame.border.width
                        visible: !cell.isVid
                        source: cell.isVid ? "" : "file://" + model.path
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    // Video placeholder
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: frame.border.width
                        visible: cell.isVid
                        color: "#0b0906"
                        Text { anchors.centerIn: parent; text: "▶"; color: "#c8b89a"; font.pixelSize: 40; opacity: 0.7 }
                    }

                    // Filename bar (current only)
                    Rectangle {
                        visible: cell.isCurrent
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        anchors.margins: frame.border.width
                        height: 26
                        color: "#aa000000"
                        Text {
                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
                            text: model.path.split("/").pop()
                            font.family: "Share Tech Mono"; font.pixelSize: 11
                            color: Theme.fg; elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (cell.isCurrent) root.applyWallpaper(model.path);
                        else carousel.currentIndex = index;
                    }
                }
            }
        }

        // Left / right click targets
        Text {
            anchors { left: parent.left; leftMargin: 30; verticalCenter: parent.verticalCenter }
            text: "‹"
            font.family: "Share Tech Mono"; font.pixelSize: 48
            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3)
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: carousel.decrementCurrentIndex() }
        }
        Text {
            anchors { right: parent.right; rightMargin: 30; verticalCenter: parent.verticalCenter }
            text: "›"
            font.family: "Share Tech Mono"; font.pixelSize: 48
            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3)
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: carousel.incrementCurrentIndex() }
        }

        // Footer
        Item {
            id: footer
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; bottomMargin: 24 }
            height: 20
            Text {
                anchors.centerIn: parent
                text: "← → / H L  NAVIGATE  ·  ENTER APPLY  ·  CLICK CENTER TO APPLY  ·  ESC CLOSE"
                font.family: "Share Tech Mono"; font.pixelSize: 10
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.55)
                font.letterSpacing: 1
            }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "WallpaperPicker {}" ];
}

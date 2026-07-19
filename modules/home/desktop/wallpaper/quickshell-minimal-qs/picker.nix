{ pkgs, ... }:

# WallpaperState service + picker overlay. Self-contained — importing this file
# is all that's needed for wallpaper management.
# Images → awww img (fade). Videos (mp4/mkv/webm/avi/mov/gif) → mpvpaper (loop).
# Keyboard: arrows + Enter apply, Esc closes.

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

        Process {
            id: writer
            running: false
        }

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
        color: "transparent"
        anchors { top: true; left: true; right: true; bottom: true }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        IpcHandler {
            target: "wallpaperPicker"
            function toggle() {
                if (!root.visible) {
                    wallpapers.clear();
                    scanner.running = true;
                }
                root.visible = !root.visible;
                if (root.visible) grid.forceActiveFocus();
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
                    if (p.length > 0) wallpapers.append({ path: p });
                }
            }
        }

        Process {
            id: applier
            running: false
        }

        Rectangle {
            anchors.fill: parent
            color: "#aa000000"
            MouseArea {
                anchors.fill: parent
                onClicked: root.visible = false
            }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 1000
            height: 660
            radius: 12
            color: Theme.bg

            MouseArea { anchors.fill: parent }

            Item {
                id: hdr
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                height: 28

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Wallpapers — " + Theme.wallpaperDir
                    color: Theme.fg
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    font.family: "FiraMono Nerd Font"
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"
                    color: Theme.fg
                    font.pixelSize: 18
                    font.family: "FiraMono Nerd Font"
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.visible = false
                    }
                }
            }

            GridView {
                id: grid
                anchors.top: hdr.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 16
                cellWidth: 320
                cellHeight: 210
                clip: true
                model: wallpapers
                keyNavigationEnabled: true
                focus: true

                Keys.onEscapePressed: root.visible = false
                Keys.onReturnPressed: {
                    if (currentIndex >= 0 && currentIndex < count)
                        root.applyWallpaper(model.get(currentIndex).path);
                }

                delegate: Item {
                    id: cell
                    width: grid.cellWidth
                    height: grid.cellHeight

                    property bool isActive:     WallpaperState.currentPath === model.path
                    property bool isKeyFocused: GridView.isCurrentItem
                    property bool isVid:        root.isVideo(model.path)

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 6
                        radius: 8
                        color: "transparent"
                        border.color: cell.isActive     ? Theme.selection
                                    : cell.isKeyFocused ? Qt.rgba(1, 1, 1, 0.5)
                                    : "transparent"
                        border.width: 2

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: parent.border.width
                            radius: parent.radius
                            color: Theme.surface
                            clip: true

                            Image {
                                anchors.fill: parent
                                visible: !cell.isVid
                                source: cell.isVid ? "" : "file://" + model.path
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            Item {
                                anchors.fill: parent
                                visible: cell.isVid

                                Rectangle { anchors.fill: parent; color: "#1a1a2e" }

                                Text {
                                    anchors.centerIn: parent
                                    text: "▶"
                                    color: "white"
                                    font.pixelSize: 48
                                    opacity: 0.75
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                grid.currentIndex = index;
                                root.applyWallpaper(model.path);
                            }
                        }
                    }
                }
            }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "WallpaperPicker {}" ];
}

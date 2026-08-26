{ ... }:

# Services/WallpaperState.qml — per-monitor wallpaper and accent.
#
# Single JSON state file rather than one file per monitor: FileView paths are
# static per instance, so a file-per-monitor scheme would need an Instantiator
# building FileViews over Quickshell.screens. One watched file keyed by monitor
# name is the same information with a fraction of the machinery.

{
  quickshell.services.WallpaperState = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        readonly property string statePath:
            Quickshell.env("HOME") + "/.local/state/quickshell/wallpapers.json"

        // { "<monitor>": { "path": "...", "accent": "#RRGGBB" } }
        property var entries: ({})

        // Same value as Glass.accentFallback. Duplicated rather than imported
        // so Services never has to reach back into Common.
        readonly property color fallback: "#EDF0F5"

        FileView {
            id: stateFile
            path: root.statePath
            watchChanges: true
            onFileChanged: reload()
            onLoaded: {
                try {
                    const parsed = JSON.parse(text());
                    if (parsed && typeof parsed === "object")
                        root.entries = parsed;
                } catch (e) {
                    // Half-written file mid-`mv`; the next change re-fires.
                }
            }
        }

        function entryFor(name) {
            return (name && root.entries[name]) ? root.entries[name] : null;
        }

        function pathFor(name) {
            const e = root.entryFor(name);
            return (e && e.path) ? e.path : "";
        }

        function accentFor(name) {
            const e = root.entryFor(name);
            const a = e ? e.accent : "";
            return (a && /^#[0-9A-Fa-f]{6}$/.test(a)) ? a : root.fallback;
        }

        Process { id: applier; running: false }

        // Fire and forget: glass-wallpaper applies the image to that output,
        // derives the accent and rewrites the state file, which lands back
        // here through the FileView above.
        function apply(monitor, path) {
            if (!monitor || !path) return;
            applier.command = [ "glass-wallpaper", monitor, path ];
            applier.running = true;
        }
    }
  '';
}

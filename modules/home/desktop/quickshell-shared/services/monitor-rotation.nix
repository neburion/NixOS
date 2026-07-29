{ hostConfig, pkgs, ... }:

# Runtime external-monitor rotation. Persists to
# ~/.local/state/monitor-external-transform and re-applies:
#   - on quickshell startup (Component.onCompleted)
#   - on every Hyprland `configreloaded` event (nix rebuilds drop the transform)

let
  ext = hostConfig.displays.monitors.external;
in
{
  quickshell.services.MonitorRotation = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import Quickshell.Hyprland
    import QtQuick

    Singleton {
        id: root

        readonly property string monName:  "${ext.name}"
        readonly property string monMode:  "${ext.mode}"
        readonly property string monPos:   "${ext.position}"
        readonly property string monScale: "${ext.scale}"
        readonly property string statePath: Quickshell.env("HOME") + "/.local/state/monitor-external-transform"

        property int transform: 0
        property bool loaded: false

        Process { id: setter; running: false }
        Process { id: persister; running: false }

        Process {
            id: loader
            command: [ "sh", "-c", "cat \"$1\" 2>/dev/null || echo 0", "sh", statePath ]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    var v = parseInt(text.trim());
                    root.transform = (v === 3) ? 3 : 0;
                    root.loaded = true;
                    root.apply();
                }
            }
        }

        function apply() {
            setter.command = [
                "${pkgs.hyprland}/bin/hyprctl", "keyword", "monitor",
                monName + "," + monMode + "," + monPos + "," + monScale +
                    ",transform," + root.transform
            ];
            setter.running = true;
        }

        function persist() {
            persister.command = [
                "sh", "-c",
                "mkdir -p \"$(dirname \"$1\")\" && printf %s \"$2\" > \"$1\"",
                "sh", statePath, String(root.transform)
            ];
            persister.running = true;
        }

        function toggle() {
            root.transform = (root.transform === 0) ? 3 : 0;
            root.apply();
            root.persist();
        }

        Connections {
            target: Hyprland
            function onRawEvent(event) {
                if (!root.loaded) return;
                if (String(event).indexOf("configreloaded") >= 0) {
                    root.apply();
                }
            }
        }

        Component.onCompleted: loader.running = true
    }
  '';
}

{ hostConfig, ... }:

# External-monitor rotation, as seen by the bar.
#
# This singleton deliberately owns NO geometry. It reads the transform that
# `rotate-monitor` persisted and delegates every change back to that script.
#
# It used to run `hyprctl keyword monitor <name>,<mode>,<pos>,<scale>,transform,N`
# itself, with <pos> baked from hostConfig at build time — and that was a bug
# with three faces. The declared positions in hardware-layout are computed for
# landscape, so once a monitor is rotated its effective width shrinks
# (2560 -> 1440) and `reflow-monitors` repacks the outputs left to right.
# Re-asserting the declared position afterwards put the monitor back where a
# landscape layout wanted it, overlapping whatever reflow had already moved up
# behind it. Hyprland then logged "Monitor <name> overlaps with other
# monitor(s) in the layout" and windows stretched across the seam.
#
# It fired on quickshell start (Component.onCompleted), on every
# `configreloaded` — which every nix rebuild triggers — and on every toggle,
# which is exactly when the breakage was reported.
#
# There is no need for any of it: wm/hyprland/rotation.nix already restores
# every persisted transform on login (exec-once) and on `configreloaded` (a
# systemd socket2 watcher), and reflows afterwards. Two mechanisms racing over
# the same state, one of them without the reflow, is the whole defect.

let
  ext = hostConfig.displays.monitors.external;
in
{
  quickshell.services.MonitorRotation = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        readonly property string monName: "${ext.name}"
        readonly property string statePath:
            Quickshell.env("HOME") + "/.local/state/monitor-transforms/" + monName

        // 0 = landscape, 3 = portrait. Mirrors rotate-monitor's own encoding.
        property int transform: 0

        // Watched, not read once: `$mod + backslash` and any other caller of
        // rotate-monitor writes this file too, and the bar should follow.
        FileView {
            id: stateFile
            path: root.statePath
            watchChanges: true
            onFileChanged: reload()
            onLoaded: {
                const v = parseInt(text().trim());
                root.transform = (v === 3) ? 3 : 0;
            }
        }

        Process { id: rotator; running: false }

        // rotate-monitor flips the transform, persists it, and reflows the
        // outputs. The FileView above brings the new value back here.
        function toggle() {
            rotator.command = [ "rotate-monitor", root.monName ];
            rotator.running = true;
        }

        // One-shot migration of the pre-per-monitor state file.
        Process {
            id: migrator
            command: [
                "sh", "-c",
                "old=\"$HOME/.local/state/monitor-external-transform\"; " +
                "new=\"$1\"; " +
                "if [ -f \"$old\" ] && [ ! -f \"$new\" ]; then " +
                "  mkdir -p \"$(dirname \"$new\")\" && mv \"$old\" \"$new\"; " +
                "fi",
                "sh", statePath
            ]
            running: true
        }
    }
  '';
}

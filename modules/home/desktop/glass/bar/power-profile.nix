{ pkgs, ... }:

# PowerProfile service. Service copied from clean; `set` replaced `cycle`
# because the dial's menu shows all three states at once — cycling blind
# through a list is only worth it when there is nowhere to draw the list.
#
# The colour belongs here rather than in the widget: the profile is the thing
# that has three states, and the bar's outer ring is only borrowing them.

{
  quickshell.services.PowerProfile = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        property string current: "balanced"

        readonly property var profiles: [
            { id: "power-saver",  label: "Eco"         },
            { id: "balanced",     label: "Balanced"    },
            { id: "performance",  label: "Performance" }
        ]

        // Green idling, amber working, red burning. The amber sits close to
        // some wallpaper accents, but it is the only ring on the outside, so
        // position still tells you which one it is.
        readonly property color tint:
              root.current === "power-saver" ? "#7BD88F"
            : root.current === "performance" ? "#FF5A3C"
            :                                  "#E8913A"

        readonly property bool burning: root.current === "performance"

        Process {
            id: getProfile
            command: [ "${pkgs.power-profiles-daemon}/bin/powerprofilesctl", "get" ]
            running: false
            stdout: StdioCollector { onStreamFinished: root.current = text.trim() }
        }

        Process { id: setProfile; running: false }
        Process { id: vfr;        running: false }

        function refresh() { getProfile.running = true; }

        function set(next) {
            if (next === root.current) return;

            setProfile.command = [ "${pkgs.power-profiles-daemon}/bin/powerprofilesctl", "set", next ];
            setProfile.running = true;
            root.current = next;

            // `keyword` is a hyprctl command, not a dispatcher, so the clean
            // preset's Hyprland.dispatch("keyword misc:vfr N") has always
            // failed with "Invalid dispatcher" — the VFR setting never moved.
            // Run it as what it is.
            vfr.command = [
                "${pkgs.hyprland}/bin/hyprctl", "keyword", "misc:vfr",
                next === "performance" ? "0" : "1"
            ];
            vfr.running = true;
        }

        Timer { interval: 10000; running: true; triggeredOnStart: true; repeat: true; onTriggered: root.refresh() }
    }
  '';
}

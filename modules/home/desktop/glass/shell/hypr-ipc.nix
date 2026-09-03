{ ... }:

# Services/HyprlandIpc.qml — Hyprland state, plus the screen lookup three
# different modules need.
#
# This lives in the shared layer rather than in the bar because the launcher,
# the power menu and the wallpaper picker all read it too. It was originally
# registered by bar/quickshell-glass/workspaces.nix, which quietly made every
# other component depend on the bar being imported.

{
  quickshell.services.HyprlandIpc = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Hyprland
    import QtQuick

    Singleton {
        id: root

        readonly property var workspaces:     Hyprland.workspaces
        readonly property var monitors:       Hyprland.monitors
        readonly property var focused:        Hyprland.focusedWorkspace
        readonly property var focusedMonitor: Hyprland.focusedMonitor
        readonly property var focusedClient:  Hyprland.focusedClient

        readonly property string focusedName:
            root.focusedMonitor ? root.focusedMonitor.name : ""

        // The ShellScreen behind the focused HyprlandMonitor.
        //
        // Worth the lookup rather than using HyprlandMonitor directly: it has
        // no `transform` property, and its width/height are the physical mode,
        // so a rotated screen still reports 2560x1440 there. ShellScreen is
        // rotation-aware — and it is also what PanelWindow.screen wants.
        readonly property var focusedScreen: {
            const name = root.focusedName;
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++)
                if (screens[i].name === name) return screens[i];
            return null;
        }

        // "Is it taller than it is wide" — the question that actually matters
        // when picking a wallpaper, and correct for a natively portrait panel
        // as well as a rotated landscape one.
        readonly property string focusedOrientation:
            (root.focusedScreen && root.focusedScreen.height > root.focusedScreen.width)
                ? "Vertical" : "Horizontal"

        function dispatch(cmd) { Hyprland.dispatch(cmd); }
    }
  '';
}

{ ... }:

# Owns the active theme name. Persists to ~/.local/state/quickshell/active-theme
# and delegates external consumer sync to `theme-set` (from the
# theme-switcher module) — the switcher iterates every registered themeHooks
# entry with baked /nix/store paths.

{
  quickshell.services.ThemeState = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        property string activeName: "dark"

        FileView {
            id: stateFile
            path: `''${Quickshell.env("HOME")}/.local/state/quickshell/active-theme`
            watchChanges: true
            onFileChanged: reload()
            onLoaded: {
                var raw = text().trim();
                if (raw.length > 0 && raw !== root.activeName) {
                    root.activeName = raw;
                }
            }
        }

        Process {
            id: sync
            running: false
        }

        function setActive(name) {
            if (!name || name === root.activeName) return;
            root.activeName = name;
            stateFile.setText(name + "\n");

            // Fire and forget external consumer sync.
            sync.command = [ "theme-set", name ];
            sync.running = true;
        }
    }
  '';
}

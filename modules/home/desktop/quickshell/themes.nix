{ lib, themes, ... }:

# Bakes palette data into Common/Theme.qml. Consumers access Theme.bg, Theme.fg,
# etc — the values are reactive to ThemeState.activeName, so a theme change
# rerenders everything that binds to Theme.*.

let
  mkPaletteEntry = name: t: ''
    "${name}": ({
      "bg":             "${t.bg}",
      "surface":        "${t.surface}",
      "selection":      "${t.selection}",
      "fg":             "${t.fg}",
      "wallpaperDir":   "${t.wallpaperDir}",
      "gtkTheme":       "${t.gtkTheme}",
      "fishPrimary":    "${t.fishPrimary}",
      "fishSecondary":  "${t.fishSecondary}",
      "superfileTheme": "${t.superfileTheme}",
      "nvimTheme":      "${t.nvimTheme}",
      "zedTheme":       "${t.zedTheme}"
    })'';

  paletteEntries = lib.concatStringsSep ",\n    " (lib.mapAttrsToList mkPaletteEntry themes);
in
{
  quickshell.commons.Theme = ''
    pragma Singleton
    import Quickshell
    import QtQuick
    import "../Services"

    Singleton {
        id: root

        readonly property var palettes: ({
            ${paletteEntries}
        })

        // Falls back to "dark" until ThemeState boots.
        readonly property string activeName: ThemeState.activeName || "dark"
        readonly property var current: palettes[activeName] || palettes["dark"]

        readonly property color bg:             current.bg
        readonly property color surface:        current.surface
        readonly property color selection:      current.selection
        readonly property color fg:             current.fg
        readonly property string wallpaperDir:   current.wallpaperDir
        readonly property string gtkTheme:       current.gtkTheme
        readonly property color fishPrimary:    current.fishPrimary
        readonly property color fishSecondary:  current.fishSecondary
        readonly property string superfileTheme: current.superfileTheme
        readonly property string nvimTheme:      current.nvimTheme
        readonly property string zedTheme:       current.zedTheme

        readonly property color warning: "#dc381f"

        readonly property var names: Object.keys(palettes)
    }
  '';
}

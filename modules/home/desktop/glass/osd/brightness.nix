{ hostConfig, ... }:

# BrightnessState service (verbatim from clean — sysfs paths baked at build
# time from hostConfig.backlight) + the glass OSD pill.

let
  bp  = hostConfig.backlight.sysfsBrightnessPath;
  mbp = hostConfig.backlight.sysfsMaxBrightnessPath;
in
{
  quickshell.services.BrightnessState = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        property int brightness:    0
        property int maxBrightness: 100
        property int percent: maxBrightness > 0
            ? Math.round(brightness / maxBrightness * 100)
            : 0

        FileView {
            path: "${bp}"
            watchChanges: true
            onFileChanged: reload()
            onLoaded: {
                var v = parseInt(text().trim());
                if (!isNaN(v)) root.brightness = v;
            }
        }

        FileView {
            path: "${mbp}"
            onLoaded: {
                var v = parseInt(text().trim());
                if (!isNaN(v)) root.maxBrightness = v;
            }
        }
    }
  '';

  quickshell.modules.OsdBrightness = ''
    import QtQuick
    import "../Services"
    import "../Common"
    import "../Widgets"

    OsdPill {
        id: root
        glyph:   ""
        percent: BrightnessState.percent

        // First read on startup would otherwise pop the OSD unprompted.
        property bool primed: false

        Connections {
            target: BrightnessState
            function onBrightnessChanged() {
                if (!root.primed) { root.primed = true; return; }
                root.show();
            }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "OsdBrightness {}" ];
}

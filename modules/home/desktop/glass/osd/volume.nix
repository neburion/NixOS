{ ... }:

{
  quickshell.modules.OsdVolume = ''
    import QtQuick
    import "../Services"
    import "../Common"
    import "../Widgets"

    OsdPill {
        id: root
        glyph: Audio.muted     ? ""
             : Audio.volume > 66 ? ""
             : Audio.volume > 0  ? ""
             :                     ""
        percent: Audio.volume
        dimmed:  Audio.muted

        Connections {
            target: Audio
            function onVolumeChanged() { root.show(); }
            function onMutedChanged()  { root.show(); }
        }
    }
  '';

  quickshell.moduleInstantiations = [ "OsdVolume {}" ];
}

{ pkgs, ... }:

# PipeWire/Pulse audio state. Uses Quickshell.Services.Pipewire native binding.
# Exposes default sink volume as 0-100 int, plus a mute flag.

{
  quickshell.services.Audio = ''
    pragma Singleton
    import Quickshell
    import Quickshell.Services.Pipewire
    import QtQuick

    Singleton {
        id: root

        readonly property PwNode defaultSink: Pipewire.defaultAudioSink
        readonly property int volume: defaultSink && defaultSink.audio
            ? Math.round(defaultSink.audio.volume * 100)
            : 0
        readonly property bool muted: defaultSink && defaultSink.audio
            ? defaultSink.audio.muted
            : false

        PwObjectTracker {
            objects: [ Pipewire.defaultAudioSink ]
        }

        function setVolume(v) {
            if (defaultSink && defaultSink.audio) {
                defaultSink.audio.volume = Math.max(0, Math.min(1.5, v / 100));
            }
        }

        function toggleMute() {
            if (defaultSink && defaultSink.audio) {
                defaultSink.audio.muted = !defaultSink.audio.muted;
            }
        }
    }
  '';
}

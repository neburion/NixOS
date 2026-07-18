{ ... }:

# Shared singleton for at-most-one bar popup. Popups track ownership by Item
# (per-screen instance) so clicking the WiFi icon on monitor A doesn't also
# open the WiFi popup that lives on monitor B's copy of the bar.

{
  quickshell.services.PopupState = ''
    pragma Singleton
    import QtQuick

    QtObject {
        id: root
        property Item owner: null

        function toggle(item) { root.owner = root.owner === item ? null : item; }
        function close()      { root.owner = null; }
    }
  '';
}
